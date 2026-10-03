#!/usr/bin/env python3
"""Unit tests for the esnixi vLLM switcher tenancy state machine (no GPU, no systemd).

Sleep-mode tenancy (both units co-resident, one awake at a time):
  (a) acquiring the reader puts the running coder to sleep instead of stopping it
  (b) a cold reader start issues sleep<coder> -> reset-failed<reader> ->
      start<reader>, in that order, only when active_requests==0
  (c) a coder that cannot sleep falls back to stop + drain before the start
  (d) a warm swap (both units running) is sleep<other> only: no start, no stop
  (e) busy -> 409 via acquire_model returning False on LOCK_WAIT timeout
  (f) MODELS["qwen3.5-9b-nvfp4-reader"]["context"] == the reader unit's served
      --max-model-len (65536) -- the coupling guard
Minimum-residency hysteresis (RESIDENCY_SECONDS):
  (g) a different-unit request within the window returns False (409) without
      any sleep/stop/start
  (h) after the window it swaps; (h2) a window expiring during the lock wait swaps
  (i) same-unit requests are unaffected
  (j) acquire and release stamp last_activity
  (k) a sleep request answered 409 (requests still draining) is retried
  (l) _env_seconds parsing of VLLM_SWITCH_RESIDENCY_SECONDS
Coder concurrency and nix coupling:
  (m) MODELS context/max_requests/port == maxModelLen/maxNumSeqs/port parsed from
      esnixi/vllm.nix for the coder (both aliases) and the reader
  (n) the coder admits up to max_requests concurrent requests, then 409s
  (o) requests are proxied to the selected model's own backend port
"""
import importlib.util
import os
import re
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
CODER_UNIT = "vllm.service"
READER_UNIT = "vllm-reader.service"


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


class _Resp:
    def __init__(self, body, status=200):
        self.body = body
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def read(self):
        return self.body


class FakeHost:
    """Simulates systemctl for both units plus each backend's HTTP control surface.

    `events` is one ordered log of ("start"|"stop"|"reset-failed"|"sleep", unit).
    """

    def __init__(self):
        self.events = []
        # Start with the coder active and awake (as if it was already serving).
        self.active = {CODER_UNIT: "active", READER_UNIT: "inactive"}
        self.sub = {CODER_UNIT: "running", READER_UNIT: "dead"}
        self.asleep = set()
        self.failed = set()
        self.nrestarts = {CODER_UNIT: 0, READER_UNIT: 0}
        # Per-unit scripted /arcane/sleep answers; default 200.
        self.sleep_answers = {CODER_UNIT: [], READER_UNIT: []}
        self.proxied = []
        self.lock = threading.Lock()

    @staticmethod
    def _unit_of(argv):
        return next((a for a in argv if a.endswith(".service")), None)

    def run(self, argv, **kwargs):
        tail = [a for a in argv if a not in (SW.SUDO, "-n", SW.SYSTEMCTL)]
        with self.lock:
            verb = tail[0] if tail else ""
            unit = self._unit_of(tail)
            if verb == "is-failed":
                return types.SimpleNamespace(returncode=0 if unit in self.failed else 1)
            if verb in ("start", "stop", "reset-failed") and unit:
                self.events.append((verb, unit))
            if verb == "reset-failed" and unit:
                self.failed.discard(unit)
            elif verb == "start" and unit:
                self.active[unit], self.sub[unit] = "active", "running"
                self.asleep.discard(unit)
            elif verb == "stop" and unit:
                self.active[unit], self.sub[unit] = "inactive", "dead"
                self.asleep.discard(unit)
            return types.SimpleNamespace(returncode=0)

    def check_output(self, argv, **kwargs):
        tail = [a for a in argv if a not in (SW.SUDO, "-n", SW.SYSTEMCTL)]
        unit = self._unit_of(tail)
        with self.lock:
            if "--property=NRestarts" in tail:
                return str(self.nrestarts.get(unit, 0))
            if "--property=ActiveState" in tail:
                return f"{self.active.get(unit, 'inactive')}\n{self.sub.get(unit, 'dead')}\n"
        return ""

    def urlopen(self, request, timeout=0):
        url = request.full_url if hasattr(request, "full_url") else request
        match = re.match(r"http://127\.0\.0\.1:(\d+)(/[^?]*)", url)
        port, path = int(match.group(1)), match.group(2)
        unit = next(m["unit"] for m in SW.MODELS.values() if m["port"] == port)
        with self.lock:
            running = self.active.get(unit) == "active"
            if path == "/arcane/sleep":
                if not running:
                    raise SW.urllib.error.URLError("connection refused")
                answers = self.sleep_answers[unit]
                status = answers.pop(0) if answers else 200
                if status != 200:
                    raise SW.urllib.error.HTTPError(url, status, "scripted", {}, None)
                self.events.append(("sleep", unit))
                self.asleep.add(unit)
                return _Resp(b'{"slept": true}')
            if path == "/v1/models":
                if not running:
                    raise SW.urllib.error.URLError("connection refused")
                model = next(m for m in SW.MODELS.values() if m["unit"] == unit)
                body = SW.json.dumps(
                    {"data": [{"id": model["served"], "max_model_len": model["context"]}]})
                return _Resp(body.encode())
            self.proxied.append((port, path))
            return _Resp(b"{}")

    def gpu_owners(self):
        """Units that are running and awake (would hold VRAM + the lease)."""
        return sorted(u for u, st in self.active.items() if st == "active" and u not in self.asleep)


class SwitcherTests(unittest.TestCase):
    CODER = "qwen3.8-27b-nvfp4"
    READER = "qwen3.5-9b-nvfp4-reader"

    def setUp(self):
        with SW.switch_condition:
            SW.active_model = None
            SW.active_requests = 0
            SW.switching = False
            SW.last_activity = None
        self._saved = {name: getattr(SW, name) for name in (
            "RESIDENCY_SECONDS", "LOCK_WAIT_SECONDS", "DRAIN_SETTLE_SECONDS",
            "SLEEP_DRAIN_SECONDS")}
        SW.DRAIN_SETTLE_SECONDS = 0
        SW.SLEEP_DRAIN_SECONDS = 3
        self.fake = FakeHost()
        self._patches = [
            mock.patch.object(SW.subprocess, "run", self.fake.run),
            mock.patch.object(SW.subprocess, "check_output", self.fake.check_output),
            mock.patch.object(SW.urllib.request, "urlopen", self.fake.urlopen),
            mock.patch.object(SW.time, "sleep", lambda s: None),
        ]
        for p in self._patches:
            p.start()

    def tearDown(self):
        for p in self._patches:
            p.stop()
        for name, value in self._saved.items():
            setattr(SW, name, value)

    def _handler(self):
        return SW.Handler.__new__(SW.Handler)

    def lifecycle(self):
        return [e for e in self.fake.events if e[0] in ("start", "stop", "sleep")]

    def _seed_active(self, model_id, age, other_running=False):
        """Make `model_id` the idle active model, last used `age` seconds ago."""
        unit = SW.MODELS[model_id]["unit"]
        with SW.switch_condition:
            SW.active_model = model_id
            SW.active_requests = 0
            SW.last_activity = time.monotonic() - age
        for u in (CODER_UNIT, READER_UNIT):
            running = u == unit or other_running
            self.fake.active[u] = "active" if running else "inactive"
            self.fake.sub[u] = "running" if running else "dead"
        self.fake.asleep = {u for u in (CODER_UNIT, READER_UNIT) if u != unit and other_running}

    def test_f_context_matches_served_max_model_len(self):
        self.assertEqual(SW.MODELS[self.READER]["context"], 65536)
        self.assertEqual(SW.MODELS[self.READER]["served"], self.READER)
        self.assertEqual(SW.MODELS[self.READER]["unit"], READER_UNIT)

    def test_a_reader_sleeps_coder_instead_of_stopping(self):
        h = self._handler()
        self.assertTrue(h.acquire_model(self.READER))
        self.assertEqual(self.fake.active[CODER_UNIT], "active")
        self.assertIn(CODER_UNIT, self.fake.asleep)
        self.assertNotIn(("stop", CODER_UNIT), self.fake.events)
        self.assertEqual(self.fake.gpu_owners(), [READER_UNIT])
        h.release_model()

    def test_b_cold_reader_start_ordering(self):
        h = self._handler()
        self.assertTrue(h.acquire_model(self.READER))
        seq = self.fake.events
        i_sleep = seq.index(("sleep", CODER_UNIT))
        i_reset = seq.index(("reset-failed", READER_UNIT))
        i_start = seq.index(("start", READER_UNIT))
        self.assertLess(i_sleep, i_reset)
        self.assertLess(i_reset, i_start)
        h.release_model()

    def test_c_sleep_failure_falls_back_to_stop(self):
        self.fake.sleep_answers[CODER_UNIT] = [500]
        h = self._handler()
        self.assertTrue(h.acquire_model(self.READER))
        seq = self.lifecycle()
        self.assertNotIn(("sleep", CODER_UNIT), seq)
        self.assertLess(seq.index(("stop", CODER_UNIT)), seq.index(("start", READER_UNIT)))
        self.assertEqual(self.fake.gpu_owners(), [READER_UNIT])
        h.release_model()

    def test_d_warm_swap_is_sleep_only(self):
        SW.RESIDENCY_SECONDS = 0
        h = self._handler()
        for seeded, requested in ((self.CODER, self.READER), (self.READER, self.CODER)):
            self.fake.events.clear()
            self._seed_active(seeded, age=0, other_running=True)
            seeded_unit = SW.MODELS[seeded]["unit"]
            self.assertTrue(h.acquire_model(requested))
            self.assertEqual(self.lifecycle(), [("sleep", seeded_unit)])
            with SW.switch_condition:
                self.assertEqual(SW.active_model, requested)
            h.release_model()

    def test_e_busy_returns_false(self):
        with SW.switch_condition:
            SW.active_model = self.CODER
            SW.active_requests = 1  # a coding generation is in flight
        SW.LOCK_WAIT_SECONDS = 0
        self.assertFalse(self._handler().acquire_model(self.READER))
        self.assertEqual(self.lifecycle(), [])
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               "vllm-switch.py")) as src:
            self.assertIn("RTX 5090 is busy; use the next OmniRoute fallback", src.read())

    def test_g_residency_blocks_swap_within_window(self):
        SW.RESIDENCY_SECONDS = 90
        SW.LOCK_WAIT_SECONDS = 0.2
        h = self._handler()
        for seeded, requested in ((self.CODER, self.READER), (self.READER, self.CODER)):
            self.fake.events.clear()
            self._seed_active(seeded, age=0, other_running=True)
            self.assertFalse(h.acquire_model(requested))
            self.assertEqual(self.lifecycle(), [])
            with SW.switch_condition:
                self.assertEqual(SW.active_model, seeded)
                self.assertIs(SW.switching, False)
                self.assertEqual(SW.active_requests, 0)

    def test_h_swaps_after_window(self):
        SW.RESIDENCY_SECONDS = 90
        self._seed_active(self.CODER, age=91)
        h = self._handler()
        self.assertTrue(h.acquire_model(self.READER))
        seq = self.lifecycle()
        self.assertLess(seq.index(("sleep", CODER_UNIT)), seq.index(("start", READER_UNIT)))
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
        self.assertIn(("start", READER_UNIT), self.fake.events)
        h.release_model()

    def test_i_same_unit_unaffected(self):
        SW.RESIDENCY_SECONDS = 90
        h = self._handler()
        self._seed_active(self.CODER, age=0)
        self.assertTrue(h.acquire_model(self.CODER))
        h.release_model()
        self.assertTrue(h.acquire_model(SW.BALANCED_MODEL_ID))
        h.release_model()
        self.assertEqual(self.lifecycle(), [])

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
        self.assertEqual(self.lifecycle(), [])
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

    def test_k_sleep_busy_is_retried(self):
        self.fake.sleep_answers[CODER_UNIT] = [409, 409]
        h = self._handler()
        self.assertTrue(h.acquire_model(self.READER))
        seq = self.lifecycle()
        self.assertIn(("sleep", CODER_UNIT), seq)
        self.assertNotIn(("stop", CODER_UNIT), seq)
        h.release_model()

    def test_l_env_seconds_parsing(self):
        name = "VLLM_SWITCH_RESIDENCY_SECONDS"
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop(name, None)
            self.assertEqual(SW._env_seconds(name, 90.0), 90.0)
        for raw, expected in (("abc", 90.0), ("-5", 90.0), ("45", 45.0), ("0", 0.0)):
            with mock.patch.dict(os.environ, {name: raw}):
                self.assertEqual(SW._env_seconds(name, 90.0), expected, raw)

    def test_m_coupling_matches_vllm_nix(self):
        coder = _nix_block("vllm")
        reader = _nix_block("vllm-reader")
        self.assertIsNotNone(coder, "vllm.service block not found in vllm.nix")
        self.assertIsNotNone(reader, "vllm-reader.service block not found in vllm.nix")
        values = {name: _nix_attr(coder, name) for name in ("maxModelLen", "maxNumSeqs", "port")}
        self.assertNotIn(None, values.values(), values)
        for mid in (self.CODER, SW.BALANCED_MODEL_ID):
            m = SW.MODELS[mid]
            self.assertEqual(m["unit"], CODER_UNIT, mid)
            self.assertEqual(m["context"], values["maxModelLen"], mid)
            self.assertEqual(m["max_requests"], values["maxNumSeqs"], mid)
            self.assertEqual(m["port"], values["port"], mid)
        self.assertEqual(SW.MODELS[self.READER]["context"], _nix_attr(reader, "maxModelLen"))
        self.assertEqual(SW.MODELS[self.READER]["port"], _nix_attr(reader, "port"))
        self.assertNotEqual(SW.MODELS[self.READER]["port"], values["port"])

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
        self.assertFalse(h.acquire_model(self.CODER))
        # A reader request cannot swap while the coder is busy, even past residency.
        SW.RESIDENCY_SECONDS = 0
        self.assertFalse(h.acquire_model(self.READER))
        self.assertEqual(self.lifecycle(), [])
        for _ in range(4):
            h.release_model()
        with SW.switch_condition:
            self.assertEqual(SW.active_requests, 0)
            self.assertEqual(SW.active_model, self.CODER)

    def test_o_proxy_uses_model_port(self):
        h = self._handler()
        h.headers = {}
        sent = []
        h.send_response = lambda status: sent.append(status)
        h.send_header = lambda *a: None
        h.end_headers = lambda: None
        h.wfile = types.SimpleNamespace(write=lambda b: None, flush=lambda: None)

        class _Upstream(_Resp):
            headers = {}

            def read1(self, n):
                return b""

        with mock.patch.object(SW.urllib.request, "urlopen",
                               lambda req, timeout=0: (self.fake.proxied.append(req.full_url),
                                                       _Upstream(b""))[1]):
            h.proxy("/v1/chat/completions", b"{}", self.READER)
            h.proxy("/v1/chat/completions", b"{}", self.CODER)
        self.assertEqual(self.fake.proxied, [
            "http://127.0.0.1:8012/v1/chat/completions",
            "http://127.0.0.1:8010/v1/chat/completions"])
        self.assertEqual(sent, [200, 200])


if __name__ == "__main__":
    unittest.main(verbosity=2)
