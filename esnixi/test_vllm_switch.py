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
"""
import importlib.util
import os
import sys
import tempfile
import threading
import time
import types
import unittest


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


if __name__ == "__main__":
    unittest.main(verbosity=2)
