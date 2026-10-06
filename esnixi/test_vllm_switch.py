#!/usr/bin/env python3
"""Unit tests for the esnixi vLLM switcher tenancy state machine (no GPU, no systemd).

Single-tenant coder lifecycle (the 27B coder is the sole 5090 sleep-mode tenant):
  (e) busy -> 409 via acquire_model returning False on LOCK_WAIT timeout
Minimum-residency hysteresis (CODER_RESIDENCY_SECONDS):
  (g) a different-unit request within the window returns False (409) without
      any sleep/stop/start
  (i) same-unit requests are unaffected
  (j) acquire and release stamp last_activity
  (l) _env_seconds parsing of VLLM_SWITCH_RESIDENCY_SECONDS
Coder concurrency and nix coupling:
  (m) MODELS context/max_requests/port == maxModelLen/maxNumSeqs/port parsed from
      esnixi/vllm.nix for the coder (both aliases)
  (n) the coder admits up to max_requests concurrent requests, then 409s
  (o) requests are proxied to the coder's own backend port
Fail-safe switching:
  (p2) a hung stop is bounded
  (u) an open breaker -> immediate 409 backoff with Retry-After, active model untouched
  (y) the watchdog readies the coder when nothing is ready; (y2) it waits for the
      threshold / an in-progress switch / the coder breaker; (y4) it clears a dead
      active model; (y5) the loop survives an exception
  (ff1) a coder start that fails once succeeds via a fast retry: no breaker;
      (ff1b) the same for a one-off NRestarts rise
  (ff2) a coder failing every attempt (1 + 2 retries) opens the breaker ONCE and
      is left stopped (no crash loop)
  (ff3) the watchdog's coder start gets the fast retry; (ff4) when every attempt
      fails, one breaker failure and the coder is stopped
  (z) vllm.nix: switcher fail-safe env parses, coder KV/gate pinned
"""
import importlib.util
import io
import json
import subprocess
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
    """Simulates systemctl for the coder unit plus its backend's HTTP control surface.

    `events` is one ordered log of ("start"|"stop"|"reset-failed"|"sleep", unit).
    """

    def __init__(self):
        self.events = []
        # Start with the coder active and awake (as if it was already serving).
        self.active = {CODER_UNIT: "active"}
        self.sub = {CODER_UNIT: "running"}
        self.asleep = set()
        self.failed = set()
        self.nrestarts = {CODER_UNIT: 0}
        # Per-unit scripted /arcane/sleep answers; default 200.
        self.sleep_answers = {CODER_UNIT: []}
        self.proxied = []
        # Failure injection.
        self.start_fails = set()       # start -> unit failed, never serves
        self.start_fail_times = {}     # unit -> remaining starts that fail like start_fails
        self.restart_once = set()      # next start bumps NRestarts and never serves
        self.restart_once_done = set()  # units whose restart_once already fired
        self.restart_on_start = set()  # start bumps NRestarts, never serves
        self.sleep_hangs = set()       # /arcane/sleep times out
        self.stop_timeout = set()      # systemctl stop raises TimeoutExpired, unit stays up
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
                if self.active.get(unit) == "failed":
                    self.active[unit], self.sub[unit] = "inactive", "dead"
            elif verb == "start" and self.start_fail_times.get(unit, 0) > 0:
                self.start_fail_times[unit] -= 1
                self.active[unit], self.sub[unit] = "failed", "failed"
                self.failed.add(unit)
            elif verb == "start" and unit in self.restart_once:
                self.restart_once.discard(unit)
                self.active[unit], self.sub[unit] = "active", "running"
                self.nrestarts[unit] += 1
                self.restart_on_start.add(unit)
                self.restart_once_done.add(unit)
            elif verb == "start" and unit in self.start_fails:
                self.active[unit], self.sub[unit] = "failed", "failed"
                self.failed.add(unit)
            elif verb == "start" and unit:
                self.active[unit], self.sub[unit] = "active", "running"
                self.asleep.discard(unit)
                if unit in self.restart_once_done:  # the one-shot restart is over
                    self.restart_once_done.discard(unit)
                    self.restart_on_start.discard(unit)
                if unit in self.restart_on_start:
                    self.nrestarts[unit] += 1
            elif verb == "stop" and unit in self.stop_timeout:
                raise subprocess.TimeoutExpired(argv, kwargs.get("timeout", 0))
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
            if path == "/arcane/state":
                if not running:
                    raise SW.urllib.error.URLError("connection refused")
                return _Resp(json.dumps({"sleeping": unit in self.asleep, "active": 0,
                                         "lease_held": unit not in self.asleep}).encode())
            if path == "/arcane/sleep":
                if not running:
                    raise SW.urllib.error.URLError("connection refused")
                if unit in self.sleep_hangs:
                    raise TimeoutError("timed out")
                answers = self.sleep_answers[unit]
                status = answers.pop(0) if answers else 200
                if status != 200:
                    raise SW.urllib.error.HTTPError(url, status, "scripted", {}, None)
                self.events.append(("sleep", unit))
                self.asleep.add(unit)
                return _Resp(b'{"slept": true}')
            if path == "/v1/models":
                if not running or unit in self.restart_on_start:
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

    def setUp(self):
        with SW.switch_condition:
            SW.active_model = None
            SW.active_requests = 0
            SW.switching = False
            SW.switching_to = None
            SW.last_activity = None
            SW.no_ready_since = time.monotonic()
            SW.breakers.clear()
        self._saved = {name: getattr(SW, name) for name in (
            "RESIDENCY_SECONDS", "CODER_RESIDENCY_SECONDS", "LOCK_WAIT_SECONDS",
            "DRAIN_SETTLE_SECONDS", "SLEEP_DRAIN_SECONDS", "STOP_SECONDS",
            "START_SECONDS", "BACKOFF_SECONDS", "BACKOFF_MAX_SECONDS",
            "WATCHDOG_SECONDS", "WATCHDOG_INTERVAL_SECONDS",
            "CODER_FAST_RETRIES", "CODER_FAST_RETRY_DELAY_SECONDS")}
        SW.DRAIN_SETTLE_SECONDS = 0
        SW.SLEEP_DRAIN_SECONDS = 3
        SW.STOP_SECONDS = 3
        SW.START_SECONDS = 3
        self.fake = FakeHost()
        self.sleeps = []  # recorded time.sleep() arguments (nothing really sleeps)
        self._patches = [
            mock.patch.object(SW.subprocess, "run", self.fake.run),
            mock.patch.object(SW.subprocess, "check_output", self.fake.check_output),
            mock.patch.object(SW.urllib.request, "urlopen", self.fake.urlopen),
            mock.patch.object(SW.time, "sleep", self.sleeps.append),
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

    def _seed_active(self, model_id, age):
        """Make `model_id` the idle active model, last used `age` seconds ago."""
        unit = SW.MODELS[model_id]["unit"]
        with SW.switch_condition:
            SW.active_model = model_id
            SW.active_requests = 0
            SW.last_activity = time.monotonic() - age
        for u in (CODER_UNIT,):
            running = u == unit
            self.fake.active[u] = "active" if running else "inactive"
            self.fake.sub[u] = "running" if running else "dead"
        self.fake.asleep = set()

    def test_e_busy_returns_false(self):
        with SW.switch_condition:
            SW.active_model = self.CODER
            # The coder is already at its max concurrency (both aliases in flight).
            SW.active_requests = SW.MODELS[self.CODER]["max_requests"]
        SW.LOCK_WAIT_SECONDS = 0
        self.assertFalse(self._handler().acquire_model(self.CODER))
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               "vllm-switch.py")) as src:
            self.assertIn("RTX 5090 is busy; use the next OmniRoute fallback", src.read())

    def test_g_residency_blocks_full_coder(self):
        SW.CODER_RESIDENCY_SECONDS = 90
        SW.LOCK_WAIT_SECONDS = 0.2
        h = self._handler()
        # The coder is resident and already at max requests: a further coder
        # request within the window is rejected without any sleep/stop/start.
        self._seed_active(self.CODER, age=0)
        with SW.switch_condition:
            SW.active_requests = SW.MODELS[self.CODER]["max_requests"]
            SW.last_activity = time.monotonic()
        self.assertFalse(h.acquire_model(self.CODER))
        self.assertEqual(self.lifecycle(), [])
        with SW.switch_condition:
            self.assertEqual(SW.active_model, self.CODER)
            self.assertIs(SW.switching, False)

    def test_i_same_unit_unaffected(self):
        SW.RESIDENCY_SECONDS = 90
        SW.CODER_RESIDENCY_SECONDS = 90
        h = self._handler()
        self._seed_active(self.CODER, age=0)
        self.assertTrue(h.acquire_model(self.CODER))
        h.release_model()
        self.assertTrue(h.acquire_model(SW.BALANCED_MODEL_ID))
        h.release_model()
        self.assertEqual(self.lifecycle(), [])

        self._seed_active(self.CODER, age=0)
        results = []
        threads = [threading.Thread(target=lambda: results.append(h.acquire_model(self.CODER)))
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
        self._seed_active(self.CODER, age=0)
        self.assertTrue(h.acquire_model(self.CODER))
        with SW.switch_condition:
            self.assertIsNotNone(SW.last_activity)
            self.assertLess(abs(time.monotonic() - SW.last_activity), 1.0)
            SW.last_activity = 0.0
        h.release_model()
        with SW.switch_condition:
            self.assertLess(abs(time.monotonic() - SW.last_activity), 1.0)

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
        self.assertIsNotNone(coder, "vllm.service block not found in vllm.nix")
        values = {name: _nix_attr(coder, name) for name in ("maxModelLen", "maxNumSeqs", "port")}
        self.assertNotIn(None, values.values(), values)
        for mid in (self.CODER, SW.BALANCED_MODEL_ID):
            m = SW.MODELS[mid]
            self.assertEqual(m["unit"], CODER_UNIT, mid)
            self.assertEqual(m["context"], values["maxModelLen"], mid)
            self.assertEqual(m["max_requests"], values["maxNumSeqs"], mid)
            self.assertEqual(m["port"], values["port"], mid)

    def test_n_coder_admits_up_to_max_requests_then_409(self):
        SW.CODER_RESIDENCY_SECONDS = 90
        SW.LOCK_WAIT_SECONDS = 0.2
        self._seed_active(self.CODER, age=0)
        h = self._handler()
        self.assertEqual(SW.MODELS[self.CODER]["max_requests"], 2)
        # Admit max_requests concurrent requests across both coder aliases (they
        # share one engine and the single active_requests counter).
        ids = [self.CODER, SW.BALANCED_MODEL_ID]
        self.assertEqual(len(ids), SW.MODELS[self.CODER]["max_requests"])
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
        self.assertEqual(results, [True] * len(ids))
        with SW.switch_condition:
            self.assertEqual(SW.active_requests, len(ids))
        self.assertFalse(h.acquire_model(self.CODER))
        self.assertEqual(self.lifecycle(), [])
        for _ in range(len(ids)):
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
            h.proxy("/v1/chat/completions", b"{}", self.CODER)
        self.assertEqual(self.fake.proxied, [
            "http://127.0.0.1:8010/v1/chat/completions"])
        self.assertEqual(sent, [200])

    # ---- fail-safe switching -------------------------------------------------

    def _post(self, model_id):
        """Drive do_POST for `model_id`; return (status, headers dict, body JSON)."""
        h = self._handler()
        body = json.dumps({"model": model_id,
                           "messages": [{"role": "user", "content": "hi"}]}).encode()
        h.path = "/v1/chat/completions"
        h.headers = {"Authorization": "Bearer " + SW.TOKEN, "Content-Length": str(len(body))}
        h.rfile = io.BytesIO(body)
        h.wfile = io.BytesIO()
        sent = {"status": None, "headers": {}}
        h.send_response = lambda status: sent.__setitem__("status", status)
        h.send_header = lambda name, value: sent["headers"].__setitem__(name, value)
        h.end_headers = lambda: None
        h.do_POST()
        return sent["status"], sent["headers"], json.loads(h.wfile.getvalue())

    def test_p2_stop_timeout_is_bounded(self):
        # A hung stop during a coder fast-retry is bounded; the coder is left
        # stopped and its breaker opens once.
        self.fake.active[CODER_UNIT], self.fake.sub[CODER_UNIT] = "inactive", "dead"
        self.fake.start_fails = {CODER_UNIT}
        self.fake.stop_timeout = {CODER_UNIT}
        SW.STOP_SECONDS = 0.3
        SW.CODER_FAST_RETRY_DELAY_SECONDS = 0
        h = self._handler()
        t0 = time.monotonic()
        self.assertFalse(h.acquire_model(self.CODER))
        self.assertLess(time.monotonic() - t0, 5.0)
        self.assertEqual(h.reject_code, "start_failed")
        with SW.switch_condition:
            self.assertIs(SW.switching, False)
            self.assertEqual(SW.breakers[CODER_UNIT]["failures"], 1)

    def test_u_breaker_open_immediate_409_active_untouched(self):
        # The coder's breaker is open after a failed start; a fresh request gets an
        # immediate 409 backoff with Retry-After and never touches the active model.
        self._seed_active(self.CODER, age=200)
        with SW.switch_condition:
            SW.record_failure(CODER_UNIT, "test")
        self.fake.events.clear()
        SW.LOCK_WAIT_SECONDS = 3
        with SW.switch_condition:
            SW.active_model = None
            SW.no_ready_since = time.monotonic() - 200
        t0 = time.monotonic()
        status, headers, body = self._post(self.CODER)
        self.assertLess(time.monotonic() - t0, 1.0)
        self.assertEqual(status, 409)
        self.assertEqual(body["error"]["code"], "backoff")
        self.assertIn("in backoff for", body["error"]["message"])
        self.assertGreater(int(headers["Retry-After"]), 0)
        self.assertEqual(self.fake.events, [])

    def test_y_watchdog_restores_coder_when_nothing_ready(self):
        for coder_running in (True, False):
            self.fake.events.clear()
            self.fake.active = {CODER_UNIT: "active" if coder_running else "inactive"}
            self.fake.sub = {CODER_UNIT: "running" if coder_running else "dead"}
            self.fake.asleep = {CODER_UNIT} if coder_running else set()
            with SW.switch_condition:
                SW.active_model = None
                SW.no_ready_since = time.monotonic() - 61
            SW.watchdog_tick()
            with SW.switch_condition:
                self.assertEqual(SW.active_model, self.CODER)
                self.assertIs(SW.switching, False)
            expected = [] if coder_running else [("start", CODER_UNIT)]
            self.assertEqual(self.lifecycle(), expected, coder_running)

    def test_y2_watchdog_waits_for_threshold_and_switching(self):
        self.fake.asleep = {CODER_UNIT}
        with SW.switch_condition:
            SW.no_ready_since = time.monotonic() - 10
        self.assertIsNone(SW.watchdog_tick())
        with SW.switch_condition:
            SW.no_ready_since = time.monotonic() - 61
            SW.switching = True
        self.assertIsNone(SW.watchdog_tick())
        with SW.switch_condition:
            SW.switching = False
            SW.record_failure(CODER_UNIT, "test")
        self.assertIsNone(SW.watchdog_tick())
        with SW.switch_condition:
            self.assertIsNone(SW.active_model)
        self.assertEqual(self.fake.events, [])

    def test_y4_watchdog_clears_dead_active_model(self):
        self._seed_active(self.CODER, age=5)
        self.fake.active[CODER_UNIT], self.fake.sub[CODER_UNIT] = "inactive", "dead"
        t = time.monotonic()
        self.assertEqual(SW.watchdog_tick(now=t), "cleared")
        with SW.switch_condition:
            self.assertIsNone(SW.active_model)
            self.assertEqual(SW.no_ready_since, t)

    def test_y5_watchdog_loop_survives_exception(self):
        SW.WATCHDOG_INTERVAL_SECONDS = 0.01
        calls = []
        done = threading.Event()
        stop = threading.Event()

        def flaky_tick():
            calls.append(1)
            if len(calls) == 1:
                raise RuntimeError("boom")
            done.set()

        with mock.patch.object(SW, "watchdog_tick", flaky_tick), \
                self.assertLogs("vllm.switch", "ERROR") as logs:
            thread = threading.Thread(target=SW.watchdog_loop, args=(stop,), daemon=True)
            thread.start()
            self.assertTrue(done.wait(5))
            stop.set()
            thread.join(5)
        self.assertFalse(thread.is_alive())
        self.assertTrue(any("watchdog tick failed" in line for line in logs.output))

    # ---- coder fast retry ----------------------------------------------------

    def _coder_starts(self):
        return [e for e in self.fake.events if e == ("start", CODER_UNIT)]

    def _seed_coder_stopped(self):
        """Coder stopped and nothing resident: acquiring the coder cold-starts it."""
        SW.RESIDENCY_SECONDS = 0
        SW.CODER_RESIDENCY_SECONDS = 0
        self.fake.active[CODER_UNIT], self.fake.sub[CODER_UNIT] = "inactive", "dead"
        with SW.switch_condition:
            SW.active_model = None
            SW.last_activity = None

    def test_ff1_coder_fails_once_then_fast_retry_succeeds(self):
        self._seed_coder_stopped()
        self.fake.start_fail_times = {CODER_UNIT: 1}
        h = self._handler()
        self.assertTrue(h.acquire_model(self.CODER))
        self.assertEqual(len(self._coder_starts()), 2)
        seq = self.fake.events
        first = seq.index(("start", CODER_UNIT))
        second = seq.index(("start", CODER_UNIT), first + 1)
        self.assertIn(("stop", CODER_UNIT), seq[first:second])
        self.assertIn(SW.CODER_FAST_RETRY_DELAY_SECONDS, self.sleeps)
        with SW.switch_condition:
            self.assertNotIn(CODER_UNIT, SW.breakers)
            self.assertEqual(SW.breaker_remaining(CODER_UNIT, time.monotonic()), 0)
            self.assertEqual(SW.active_model, self.CODER)
        h.release_model()

    def test_ff1b_coder_restart_once_then_fast_retry_succeeds(self):
        self._seed_coder_stopped()
        self.fake.restart_once = {CODER_UNIT}
        h = self._handler()
        self.assertTrue(h.acquire_model(self.CODER))
        self.assertEqual(len(self._coder_starts()), 2)
        with SW.switch_condition:
            self.assertNotIn(CODER_UNIT, SW.breakers)
        h.release_model()

    def test_ff2_coder_fails_every_attempt_opens_breaker_once(self):
        self.fake.active[CODER_UNIT], self.fake.sub[CODER_UNIT] = "inactive", "dead"
        self.fake.start_fails = {CODER_UNIT}
        h = self._handler()
        self.assertFalse(h.acquire_model(self.CODER))
        self.assertEqual(h.reject_code, "start_failed")
        self.assertEqual(len(self._coder_starts()), 1 + SW.CODER_FAST_RETRIES)
        self.assertEqual(self.sleeps.count(SW.CODER_FAST_RETRY_DELAY_SECONDS),
                         SW.CODER_FAST_RETRIES)
        coder_events = [e for e in self.lifecycle() if e[1] == CODER_UNIT]
        self.assertEqual(coder_events[-1], ("stop", CODER_UNIT))
        self.assertNotEqual(self.fake.active[CODER_UNIT], "active")
        with SW.switch_condition:
            self.assertEqual(SW.breakers[CODER_UNIT]["failures"], 1)
            self.assertAlmostEqual(SW.breaker_remaining(CODER_UNIT, time.monotonic()),
                                   SW.BACKOFF_SECONDS, delta=5)

    def _watchdog_cold(self):
        self.fake.active = {CODER_UNIT: "inactive"}
        self.fake.sub = {CODER_UNIT: "dead"}
        with SW.switch_condition:
            SW.active_model = None
            SW.no_ready_since = time.monotonic() - 61

    def test_ff3_watchdog_coder_fast_retry_succeeds(self):
        self._watchdog_cold()
        self.fake.start_fail_times = {CODER_UNIT: 1}
        self.assertEqual(SW.watchdog_tick(), "ready qwen3.8-27b-nvfp4")
        self.assertEqual(len(self._coder_starts()), 2)
        with SW.switch_condition:
            self.assertNotIn(CODER_UNIT, SW.breakers)
            self.assertEqual(SW.active_model, self.CODER)

    def test_ff4_watchdog_coder_always_fails_stops_coder(self):
        self._watchdog_cold()
        self.fake.start_fails = {CODER_UNIT}
        self.assertEqual(SW.watchdog_tick(), "failed")
        self.assertEqual(len(self._coder_starts()), 1 + SW.CODER_FAST_RETRIES)
        self.assertEqual(self.lifecycle()[-1], ("stop", CODER_UNIT))
        self.assertNotEqual(self.fake.active[CODER_UNIT], "active")
        with SW.switch_condition:
            self.assertEqual(SW.breakers[CODER_UNIT]["failures"], 1)
            self.assertIsNone(SW.active_model)
            self.assertIs(SW.switching, False)

    def test_z_nix_switcher_env_and_coder_gate(self):
        self.assertNotIn("restart =", _nix_block("vllm"))
        # The coder KV budget is measured against a non-resident reader; pin it.
        self.assertIn("kvCacheMemory = 5905580032;", _nix_block("vllm"))
        self.assertIn('gpuMemoryUtilization = "0.92";', _nix_block("vllm"))
        here = os.path.dirname(os.path.abspath(__file__))
        with open(os.path.join(here, "vllm.nix")) as f:
            src = f.read()
        self.assertIn("Restart = restart;", src)
        expected = {
            "VLLM_SWITCH_RESIDENCY_SECONDS": 0.0,
            "VLLM_SWITCH_CODER_RESIDENCY_SECONDS": 90.0,
            "VLLM_SWITCH_BACKOFF_SECONDS": 300.0,
            "VLLM_SWITCH_BACKOFF_MAX_SECONDS": 1800.0,
            "VLLM_SWITCH_WATCHDOG_SECONDS": 60.0,
            "VLLM_SWITCH_SLEEP_SECONDS": 90.0,
            "VLLM_SWITCH_STOP_SECONDS": 150.0,
            "VLLM_SWITCH_START_SECONDS": 300.0,
        }
        for name, value in expected.items():
            m = re.search(r'%s = "([^"]*)";' % name, src)
            self.assertIsNotNone(m, name)
            with mock.patch.dict(os.environ, {name: m.group(1)}):
                self.assertEqual(SW._env_seconds(name, -1.0), value, name)


if __name__ == "__main__":
    unittest.main(verbosity=2)
