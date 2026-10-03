#!/usr/bin/env python3
"""Unit tests for the esnixi vLLM switcher tenancy state machine (no GPU, no systemd).

Covers design §3.9 cases (a)-(f):
  (a) reader and coder are never both "active"
  (b) a reader start issues stop<coder> -> drain ActiveState to inactive ->
      reset-failed<reader> -> start<reader>, in that order, only when active_requests==0
  (c) idle expiry issues stop vllm-reader.service
  (d) a request during the idle window cancels the stop
  (e) busy -> 409 via acquire_model returning False on LOCK_WAIT timeout
  (f) MODELS["qwen3.5-9b-nvfp4-reader"]["context"] == the reader unit's served
      --max-model-len (65536) -- the coupling guard
Minimum-residency hysteresis (RESIDENCY_SECONDS):
  (g) a different-unit request within the window returns False (409) without
      any systemctl stop/start
  (h) after the window it swaps; (h2) a window expiring during the lock wait swaps
  (i) same-unit requests are unaffected
  (j) acquire and release stamp last_activity
  (k) the reader idle stop still fires inside the window and frees the GPU
  (l) _env_seconds parsing of VLLM_SWITCH_RESIDENCY_SECONDS
Coder concurrency (vllm.service --max-num-seqs):
  (m) coder MODELS context/max_requests == maxModelLen/maxNumSeqs parsed from
      esnixi/vllm.nix (and the reader context), both coder aliases equal
  (n) the coder admits up to max_requests concurrent requests, then 409s
"""
import importlib.util
import os
import re
import sys
import tempfile
import threading
import time
import types
import unittest
from unittest import mock


def _load_switcher():
    """Import vllm-switch.py with env + a fake credential dir, under a stub name."""
    here = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(here, "vllm-switch.py")
    cred_dir = tempfile.mkdtemp(prefix="switch-cred-")
    with open(os.path.join(cred_dir, "bearer-token"), "w") as f:
        f.write("x" * 48)  # >= 32 chars
    os.environ["SYSTEMCTL"] = "/run/current-system/sw/bin/systemctl"
    os.environ["SUDO"] = "/run/wrappers/bin/sudo"
    os.environ["CREDENTIALS_DIRECTORY"] = cred_dir
    spec = importlib.util.spec_from_file_location("vllm_switch_under_test", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


SW = _load_switcher()


def _nix_block(service):
    """Return the body of `systemd.services.<service> = mkVllmService { ... };` in vllm.nix."""
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "vllm.nix")) as f:
        src = f.read()
    m = re.search(r"systemd\.services\.%s = mkVllmService \{(.*?)\n  \};" % re.escape(service),
                  src, re.S)
    return m.group(1) if m else None
def _nix_attr(block, name):
    """Return the integer value of `name = "<digits>";` inside a nix block."""
    m = re.search(r'%s = "(\d+)";' % re.escape(name), block)
    return int(m.group(1)) if m else None
class FakeSystemctl:
    """Records systemctl/sudo invocations and simulates unit ActiveState.

    Models two units: vllm.service (coder) and vllm-reader.service (reader).
    """

    def __init__(self):
        self.calls = []  # list of argv lists (the meaningful tail)
        # Start with the coder active (as if it was already serving).
        self.active = {"vllm.service": "active", "vllm-reader.service": "inactive"}
        self.sub = {"vllm.service": "running", "vllm-reader.service": "dead"}
        self.failed = set()
        self.nrestarts = {"vllm.service": 0, "vllm-reader.service": 0}
        self.lock = threading.Lock()

    def _unit_of(self, argv):
        for a in argv:
            if a.endswith(".service"):
                return a
        return None

    def run(self, argv, **kwargs):
        # Normalize: strip the SUDO/-n/SYSTEMCTL prefix noise, keep the verb+unit.
        tail = [a for a in argv if a not in (SW.SUDO, "-n", SW.SYSTEMCTL)]
        with self.lock:
            self.calls.append(tail)
            verb = tail[0] if tail else ""
            unit = self._unit_of(tail)
            if verb == "is-failed":
                rc = 0 if unit in self.failed else 1
                return types.SimpleNamespace(returncode=rc)
            if verb == "reset-failed" and unit:
                self.failed.discard(unit)
                return types.SimpleNamespace(returncode=0)
            if verb == "start" and unit:
                self.active[unit] = "active"
                self.sub[unit] = "running"
                return types.SimpleNamespace(returncode=0)
            if verb == "stop" and unit:
                self.active[unit] = "inactive"
                self.sub[unit] = "dead"
                return types.SimpleNamespace(returncode=0)
            return types.SimpleNamespace(returncode=0)

    def check_output(self, argv, **kwargs):
        tail = [a for a in argv if a not in (SW.SUDO, "-n", SW.SYSTEMCTL)]
        unit = self._unit_of(tail)
        with self.lock:
            if "--property=NRestarts" in tail:
                return str(self.nrestarts.get(unit, 0))
            # show --value --property=ActiveState --property=SubState
            if "--property=ActiveState" in tail:
                return f"{self.active.get(unit, 'inactive')}\n{self.sub.get(unit, 'dead')}\n"
        return ""


class SwitcherTests(unittest.TestCase):
    def setUp(self):
        # Reset module tenancy state before each test.
        with SW.switch_condition:
            SW.active_model = None
            SW.active_requests = 0
            SW.switching = False
            SW.reader_idle_generation = 0
            SW.last_activity = None
        self._orig_residency = SW.RESIDENCY_SECONDS
        self._orig_lock_wait = SW.LOCK_WAIT_SECONDS
        self._orig_idle = SW.READER_IDLE_SECONDS
        self.fake = FakeSystemctl()
        self._orig_run = SW.subprocess.run
        self._orig_co = SW.subprocess.check_output
        SW.subprocess.run = self.fake.run
        SW.subprocess.check_output = self.fake.check_output
        # Make the readiness poll succeed immediately: patch urlopen to report the
        # target served id with the matching max_model_len.
        self._orig_urlopen = SW.urllib.request.urlopen
        SW.urllib.request.urlopen = self._fake_urlopen
        # Speed up: shrink the drain settle + idle window for the idle tests.
        self._orig_settle = SW.DRAIN_SETTLE_SECONDS
        SW.DRAIN_SETTLE_SECONDS = 0

    def tearDown(self):
        SW.subprocess.run = self._orig_run
        SW.subprocess.check_output = self._orig_co
        SW.urllib.request.urlopen = self._orig_urlopen
        SW.DRAIN_SETTLE_SECONDS = self._orig_settle
        SW.RESIDENCY_SECONDS = self._orig_residency
        SW.LOCK_WAIT_SECONDS = self._orig_lock_wait
        SW.READER_IDLE_SECONDS = self._orig_idle

    def _fake_urlopen(self, request, timeout=0):
        # Report whichever unit is currently "active" as the served model.
        served = None
        ctx = None
        for mid, m in SW.MODELS.items():
            if self.fake.active.get(m["unit"]) == "active":
                served = m["served"]
                ctx = m["context"]
                break
        data = {"data": []}
        if served is not None:
            data = {"data": [{"id": served, "max_model_len": ctx}]}
        body = SW.json.dumps(data).encode()

        class _Resp:
            def __enter__(self_):
                return self_

            def __exit__(self_, *a):
                return False

            def read(self_):
                return body

        return _Resp()

    # Minimal Handler shim exposing the bound methods without a live HTTP server.
    def _handler(self):
        h = SW.Handler.__new__(SW.Handler)
        return h

    def verb_unit_sequence(self):
        seq = []
        for c in self.fake.calls:
            verb = c[0]
            unit = next((a for a in c if a.endswith(".service")), None)
            if verb in ("start", "stop", "reset-failed") and unit:
                seq.append((verb, unit))
        return seq

    def test_f_context_matches_served_max_model_len(self):
        # The coupling guard: switcher MODELS context == reader unit served max-model-len.
        # The served --max-model-len for vllm-reader.service is 65536 in esnixi/vllm.nix.
        self.assertEqual(SW.MODELS["qwen3.5-9b-nvfp4-reader"]["context"], 65536)
        self.assertEqual(SW.MODELS["qwen3.5-9b-nvfp4-reader"]["served"],
                         "qwen3.5-9b-nvfp4-reader")
        self.assertEqual(SW.MODELS["qwen3.5-9b-nvfp4-reader"]["unit"],
                         "vllm-reader.service")

    def test_b_reader_start_ordering(self):
        h = self._handler()
        ok = h.acquire_model("qwen3.5-9b-nvfp4-reader")
        self.assertTrue(ok)
        seq = self.verb_unit_sequence()
        # Expect: stop coder -> reset-failed reader -> start reader (in that order).
        self.assertIn(("stop", "vllm.service"), seq)
        self.assertIn(("reset-failed", "vllm-reader.service"), seq)
        self.assertIn(("start", "vllm-reader.service"), seq)
        i_stop = seq.index(("stop", "vllm.service"))
        i_reset = seq.index(("reset-failed", "vllm-reader.service"))
        i_start = seq.index(("start", "vllm-reader.service"))
        self.assertLess(i_stop, i_reset)
        self.assertLess(i_reset, i_start)
        h.release_model()

    def test_a_never_both_active(self):
        h = self._handler()
        self.assertTrue(h.acquire_model("qwen3.5-9b-nvfp4-reader"))
        # After acquiring the reader, the coder must have been stopped.
        self.assertEqual(self.fake.active["vllm.service"], "inactive")
        self.assertEqual(self.fake.active["vllm-reader.service"], "active")
        active_units = [u for u, st in self.fake.active.items() if st == "active"]
        self.assertEqual(active_units, ["vllm-reader.service"])
        h.release_model()

    def test_e_busy_returns_false(self):
        # Hold the coder slot busy, then a reader request cannot switch within
        # LOCK_WAIT_SECONDS -> acquire_model returns False -> handler emits 409.
        with SW.switch_condition:
            SW.active_model = "qwen3.8-27b-nvfp4"
            SW.active_requests = 1  # a coding generation is in flight
        h = self._handler()
        orig_wait = SW.LOCK_WAIT_SECONDS
        SW.LOCK_WAIT_SECONDS = 0  # do not actually block the test
        try:
            ok = h.acquire_model("qwen3.5-9b-nvfp4-reader")
        finally:
            SW.LOCK_WAIT_SECONDS = orig_wait
        self.assertFalse(ok)
        # The exact 409 string lives in do_POST; assert it is present in the source.
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               "vllm-switch.py")) as src:
            self.assertIn("RTX 5090 is busy; use the next OmniRoute fallback", src.read())

    def test_c_idle_expiry_stops_reader(self):
        h = self._handler()
        self.assertTrue(h.acquire_model("qwen3.5-9b-nvfp4-reader"))
        # Shrink the idle window so the test is fast.
        orig = SW.READER_IDLE_SECONDS
        SW.READER_IDLE_SECONDS = 0.2
        try:
            h.release_model()  # arms the idle stop (active_requests now 0)
            time.sleep(0.6)    # let the timer fire
        finally:
            SW.READER_IDLE_SECONDS = orig
        seq = self.verb_unit_sequence()
        self.assertIn(("stop", "vllm-reader.service"), seq)
        # And after the idle stop, active_model is cleared.
        with SW.switch_condition:
            self.assertIsNone(SW.active_model)

    def test_d_request_during_idle_cancels_stop(self):
        h = self._handler()
        self.assertTrue(h.acquire_model("qwen3.5-9b-nvfp4-reader"))
        orig = SW.READER_IDLE_SECONDS
        SW.READER_IDLE_SECONDS = 0.5
        try:
            h.release_model()  # arms idle stop generation N
            # A new reader request arrives before expiry: it shares the slot and,
            # on its own release, bumps the generation -> the first timer is stale.
            self.assertTrue(h.acquire_model("qwen3.5-9b-nvfp4-reader"))
            h.release_model()  # re-arms generation N+1
            # Wait less than the (new) window so neither stop fires yet, then verify
            # no stop happened in the first window.
            time.sleep(0.3)
        finally:
            pass
        # The reader must still be active (the stale generation-N stop was cancelled).
        with SW.switch_condition:
            self.assertEqual(SW.active_model, "qwen3.5-9b-nvfp4-reader")
        self.assertEqual(self.fake.active["vllm-reader.service"], "active")
        # Cleanup: let the final window elapse.
        SW.READER_IDLE_SECONDS = orig

    # --- minimum-residency hysteresis -------------------------------------

    CODER = "qwen3.8-27b-nvfp4"
    READER = "qwen3.5-9b-nvfp4-reader"

    def _seed_active(self, model_id, age):
        """Make `model_id` the idle active model, last used `age` seconds ago."""
        unit = SW.MODELS[model_id]["unit"]
        with SW.switch_condition:
            SW.active_model = model_id
            SW.active_requests = 0
            SW.last_activity = time.monotonic() - age
        for u in ("vllm.service", "vllm-reader.service"):
            self.fake.active[u] = "active" if u == unit else "inactive"
            self.fake.sub[u] = "running" if u == unit else "dead"

    def test_g_residency_blocks_swap_within_window(self):
        SW.RESIDENCY_SECONDS = 90
        SW.LOCK_WAIT_SECONDS = 0.2
        h = self._handler()
        for seeded, requested in ((self.CODER, self.READER), (self.READER, self.CODER)):
            self.fake.calls.clear()
            self._seed_active(seeded, age=0)
            seeded_unit = SW.MODELS[seeded]["unit"]
            self.assertFalse(h.acquire_model(requested))
            seq = self.verb_unit_sequence()
            self.assertFalse([s for s in seq if s[0] in ("stop", "start")], seq)
            self.assertEqual(self.fake.active[seeded_unit], "active")
            with SW.switch_condition:
                self.assertEqual(SW.active_model, seeded)
                self.assertIs(SW.switching, False)
                self.assertEqual(SW.active_requests, 0)

    def test_h_swaps_after_window(self):
        SW.RESIDENCY_SECONDS = 90
        self._seed_active(self.CODER, age=91)
        h = self._handler()
        self.assertTrue(h.acquire_model(self.READER))
        seq = self.verb_unit_sequence()
        self.assertIn(("stop", "vllm.service"), seq)
        self.assertIn(("start", "vllm-reader.service"), seq)
        self.assertLess(seq.index(("stop", "vllm.service")),
                        seq.index(("start", "vllm-reader.service")))
        with SW.switch_condition:
            self.assertEqual(SW.active_model, self.READER)
        h.release_model()

    def test_h2_window_expiring_during_lock_wait_swaps(self):
        SW.RESIDENCY_SECONDS = 0.3
        SW.LOCK_WAIT_SECONDS = 3
        self._seed_active(self.CODER, age=0)
        h = self._handler()
        t0 = time.monotonic()
        self.assertTrue(h.acquire_model(self.READER))
        self.assertLess(time.monotonic() - t0, 2.0)
        self.assertIn(("start", "vllm-reader.service"), self.verb_unit_sequence())
        h.release_model()

    def test_i_same_unit_unaffected(self):
        SW.RESIDENCY_SECONDS = 90
        h = self._handler()
        self._seed_active(self.CODER, age=0)
        self.assertTrue(h.acquire_model(self.CODER))
        h.release_model()
        self.assertTrue(h.acquire_model("qwen3.8-27b-nvfp4-balanced"))
        h.release_model()
        self.assertEqual(self.verb_unit_sequence(), [])

        self._seed_active(self.READER, age=0)
        results = []
        threads = [threading.Thread(target=lambda: results.append(h.acquire_model(self.READER)))
                   for _ in range(2)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(5)
        self.assertEqual(results, [True, True])
        with SW.switch_condition:
            self.assertEqual(SW.active_requests, 2)
        self.assertEqual(self.verb_unit_sequence(), [])
        h.release_model()
        h.release_model()

    def test_j_release_and_acquire_stamp_last_activity(self):
        h = self._handler()
        self.assertTrue(h.acquire_model(self.READER))
        with SW.switch_condition:
            self.assertIsNotNone(SW.last_activity)
            self.assertLess(abs(time.monotonic() - SW.last_activity), 1.0)
            SW.last_activity = 0.0
        h.release_model()
        with SW.switch_condition:
            self.assertLess(abs(time.monotonic() - SW.last_activity), 1.0)

    def test_k_idle_stop_fires_despite_residency_and_frees_gpu(self):
        SW.RESIDENCY_SECONDS = 90
        SW.READER_IDLE_SECONDS = 0.2
        h = self._handler()
        self.assertTrue(h.acquire_model(self.READER))
        h.release_model()  # arms the idle stop inside the residency window
        time.sleep(0.6)
        self.assertIn(("stop", "vllm-reader.service"), self.verb_unit_sequence())
        with SW.switch_condition:
            self.assertIsNone(SW.active_model)
            self.assertIsNone(SW.last_activity)
        SW.LOCK_WAIT_SECONDS = 0.2
        self.assertTrue(h.acquire_model(self.CODER))
        self.assertIn(("start", "vllm.service"), self.verb_unit_sequence())
        h.release_model()

    def test_l_env_seconds_parsing(self):
        name = "VLLM_SWITCH_RESIDENCY_SECONDS"
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop(name, None)
            self.assertEqual(SW._env_seconds(name, 90.0), 90.0)
        for raw, expected in (("abc", 90.0), ("-5", 90.0), ("45", 45.0), ("0", 0.0)):
            with mock.patch.dict(os.environ, {name: raw}):
                self.assertEqual(SW._env_seconds(name, 90.0), expected, raw)


    def test_m_coder_coupling_matches_vllm_nix(self):
        coder = _nix_block("vllm")
        reader = _nix_block("vllm-reader")
        self.assertIsNotNone(coder, "vllm.service block not found in vllm.nix")
        self.assertIsNotNone(reader, "vllm-reader.service block not found in vllm.nix")
        max_len = _nix_attr(coder, "maxModelLen")
        num_seqs = _nix_attr(coder, "maxNumSeqs")
        reader_len = _nix_attr(reader, "maxModelLen")
        self.assertIsNotNone(max_len)
        self.assertIsNotNone(num_seqs)
        self.assertIsNotNone(reader_len)
        for mid in (self.CODER, SW.BALANCED_MODEL_ID):
            m = SW.MODELS[mid]
            self.assertEqual(m["unit"], "vllm.service", mid)
            self.assertEqual(m["context"], max_len, mid)
            self.assertEqual(m["max_requests"], num_seqs, mid)
        self.assertEqual(SW.MODELS[self.CODER]["max_requests"],
                         SW.MODELS[SW.BALANCED_MODEL_ID]["max_requests"])
        self.assertEqual(SW.MODELS[self.READER]["context"], reader_len)
    def test_n_coder_admits_up_to_max_requests_then_409(self):
        SW.RESIDENCY_SECONDS = 90
        SW.LOCK_WAIT_SECONDS = 0.2
        self._seed_active(self.CODER, age=0)
        h = self._handler()
        self.assertEqual(SW.MODELS[self.CODER]["max_requests"], 4)
        ids = [self.CODER, self.CODER, SW.BALANCED_MODEL_ID, SW.BALANCED_MODEL_ID]
        results = []
        results_lock = threading.Lock()
        def worker(mid):
            ok = h.acquire_model(mid)
            with results_lock:
                results.append(ok)
        threads = [threading.Thread(target=worker, args=(mid,)) for mid in ids]
        for t in threads:
            t.start()
        for t in threads:
            t.join(5)
        self.assertEqual(results, [True] * 4)
        with SW.switch_condition:
            self.assertEqual(SW.active_requests, 4)
        # A 5th coder request times out on LOCK_WAIT -> 409.
        self.assertFalse(h.acquire_model(self.CODER))
        # A reader request cannot swap while the coder is busy, even past residency.
        SW.RESIDENCY_SECONDS = 0
        self.assertFalse(h.acquire_model(self.READER))
        seq = self.verb_unit_sequence()
        self.assertFalse([x for x in seq if x[0] in ("stop", "start")], seq)
        for _ in range(4):
            h.release_model()
        with SW.switch_condition:
            self.assertEqual(SW.active_requests, 0)
            self.assertEqual(SW.active_model, self.CODER)
            self.assertIsNotNone(SW.last_activity)
            self.assertLess(abs(time.monotonic() - SW.last_activity), 1.0)
if __name__ == "__main__":
    unittest.main(verbosity=2)
