#!/usr/bin/env python3
"""Unit tests for on-demand ComfyUI on the esnixi RTX 5090 (no GPU, no systemd).

Launcher (arcane_worker_launch.py), stdlib only:
  (a) a busy shared queue lease raises Busy before any ComfyUI connection
  (b) a job waits (retrying) until ComfyUI holds the GPU lease, and only then
      takes the upstream shared lease
  (c) a keepalive re-asserts the GPU lease during the job and stops on release,
      before the upstream release
Admission (comfy_gpu_admission.py), needs aiohttp (run inside the Comfy venv):
  (d) /arcane/gpu/acquire returns 503 while another process (vLLM) holds the lease
  (e) it returns held=true and stamps last_activity once the lease is free
"""
import asyncio
import fcntl
import http.server
import importlib.util
import json
import os
import sys
import tempfile
import threading
import time
import types
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

try:
    import aiohttp  # noqa: F401
    HAVE_AIOHTTP = True
except ImportError:
    HAVE_AIOHTTP = False


class FakeComfy(http.server.ThreadingHTTPServer):
    """Answers POST /arcane/gpu/acquire: 503 for the first `refusals` calls."""

    def __init__(self, refusals):
        self.refusals = refusals
        self.calls = []
        super().__init__(("127.0.0.1", 0), FakeHandler)


class FakeHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        server = self.server
        server.calls.append((self.path, time.monotonic()))
        held = len(server.calls) > server.refusals
        body = json.dumps({"held": held}).encode()
        self.send_response(200 if held else 503)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


WORKER_SOURCE = '''
import json, os
from pathlib import Path
WARM = Path(os.environ["TEST_WARM"])
LEASE = WARM / "nextcloud-worker.lease"
EVENTS = []
class Busy(Exception):
    pass
def acquire():
    EVENTS.append("upstream_acquire")
def release():
    EVENTS.append("upstream_release")
def main():
    pass
if __name__ == "__main__":
    raise SystemExit("must be imported, not run")
'''


class LauncherTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.warm = root / "warm"
        self.warm.mkdir()
        (self.warm / "state.json").write_text(json.dumps({"state": "idle"}))
        script = root / "nextcloud_queue_worker.py"
        script.write_text(WORKER_SOURCE)
        self.comfy = None
        os.environ.update(TEST_WARM=str(self.warm), AA_WORKER_SCRIPT=str(script))

    def tearDown(self):
        if self.comfy:
            self.comfy.shutdown()
            self.comfy.server_close()
        self.tmp.cleanup()
        sys.modules.pop("nextcloud_queue_worker", None)

    def launcher(self, refusals):
        self.comfy = FakeComfy(refusals)
        threading.Thread(target=self.comfy.serve_forever, daemon=True).start()
        os.environ["AA_COMFY_URL"] = f"http://127.0.0.1:{self.comfy.server_port}"
        spec = importlib.util.spec_from_file_location("arcane_worker_launch", HERE / "arcane_worker_launch.py")
        launch = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(launch)
        launch.RETRY_SECONDS = 0.05
        launch.KEEPALIVE_SECONDS = 0.05
        worker = launch.load_worker()
        captured = {}
        worker.main = lambda: captured.update(acquire=worker.acquire, release=worker.release)
        launch.load_worker = lambda: worker
        launch.main()
        return worker, captured["acquire"], captured["release"]

    def test_a_busy_shared_lease_never_touches_comfy(self):
        worker, acquire, _release = self.launcher(refusals=0)
        worker.LEASE.mkdir()
        with self.assertRaises(worker.Busy):
            acquire()
        self.assertEqual(self.comfy.calls, [])
        self.assertEqual(worker.EVENTS, [])

    def test_a2_occupied_warm_worker_is_busy(self):
        worker, acquire, _release = self.launcher(refusals=0)
        (self.warm / "state.json").write_text(json.dumps({"state": "external"}))
        with self.assertRaises(worker.Busy):
            acquire()
        self.assertEqual(self.comfy.calls, [])

    def test_b_waits_for_gpu_before_upstream_acquire(self):
        worker, acquire, release = self.launcher(refusals=3)
        acquire()
        try:
            self.assertGreaterEqual(len(self.comfy.calls), 4)
            self.assertTrue(all(path == "/arcane/gpu/acquire" for path, _ in self.comfy.calls))
            self.assertEqual(worker.EVENTS, ["upstream_acquire"])
        finally:
            release()

    def test_c_keepalive_runs_during_job_and_stops_before_release(self):
        worker, acquire, release = self.launcher(refusals=0)
        acquire()
        before = len(self.comfy.calls)
        time.sleep(0.4)
        during = len(self.comfy.calls)
        self.assertGreater(during - before, 2, "keepalive did not re-assert the lease")
        release()
        stopped_at = len(self.comfy.calls)
        time.sleep(0.3)
        self.assertEqual(len(self.comfy.calls), stopped_at, "keepalive kept running after release")
        self.assertEqual(worker.EVENTS, ["upstream_acquire", "upstream_release"])


def load_admission(lock_path):
    """Import comfy_gpu_admission with ComfyUI/torch stubbed out."""
    routes = {}

    class Routes:
        def post(self, path):
            def register(handler):
                routes[path] = handler
                return handler
            return register

    queue = types.SimpleNamespace(get=lambda timeout=None: None, not_empty=threading.Condition(), queue=[])
    instance = types.SimpleNamespace(
        prompt_queue=queue, routes=Routes(),
        app=types.SimpleNamespace(middlewares=[], on_startup=[], on_cleanup=[]))
    sys.modules["server"] = types.SimpleNamespace(PromptServer=types.SimpleNamespace(instance=instance))
    sys.modules["torch"] = types.SimpleNamespace(cuda=types.SimpleNamespace())
    comfy = types.ModuleType("comfy")
    comfy.model_management = types.SimpleNamespace(current_loaded_models=[])
    sys.modules["comfy"] = comfy
    sys.modules["comfy.model_management"] = comfy.model_management
    os.environ["ARCANE_GPU_LOCK"] = lock_path
    os.environ.pop("ARCANE_GPU_LOCK_FD", None)
    spec = importlib.util.spec_from_file_location("comfy_gpu_admission", HERE / "comfy_gpu_admission.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module, routes


@unittest.skipUnless(HAVE_AIOHTTP, "aiohttp not installed (run inside the ComfyUI venv)")
class AdmissionAcquireTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.lock_path = os.path.join(self.tmp.name, "5090.lock")
        open(self.lock_path, "w").close()
        self.module, self.routes = load_admission(self.lock_path)
        self.module.ACQUIRE_WAIT_SECONDS = 0.3

    def tearDown(self):
        self.tmp.cleanup()

    def call(self):
        async def run():
            # The admission's asyncio.Lock must be created on this loop.
            self.module.admission.lock = asyncio.Lock()
            return await self.routes["/arcane/gpu/acquire"](None)
        return asyncio.run(run())

    def test_d_503_while_vllm_holds_the_lease(self):
        vllm_fd = os.open(self.lock_path, os.O_RDWR)
        fcntl.flock(vllm_fd, fcntl.LOCK_EX)
        try:
            response = self.call()
            self.assertEqual(response.status, 503)
            self.assertFalse(self.module.admission.lease.held)
        finally:
            os.close(vllm_fd)

    def test_e_acquires_and_stamps_activity_when_free(self):
        self.module.admission.last_activity = 0.0
        response = self.call()
        self.assertEqual(response.status, 200)
        self.assertEqual(json.loads(response.body), {"held": True})
        self.assertTrue(self.module.admission.lease.held)
        self.assertGreater(self.module.admission.last_activity, 0.0)
        # The lease is really exclusive now: another opener cannot take it.
        other = os.open(self.lock_path, os.O_RDWR)
        try:
            with self.assertRaises(BlockingIOError):
                fcntl.flock(other, fcntl.LOCK_EX | fcntl.LOCK_NB)
        finally:
            os.close(other)


if __name__ == "__main__":
    unittest.main()
