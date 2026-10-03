#!/usr/bin/env python3
"""Unit tests for vllm_idle.py (sleep-mode middleware), with a fake engine and lease.

  (a) POST /arcane/sleep sleeps the engine and releases the lease
  (b) an engine request re-acquires the lease and wakes before the app runs
  (c) /arcane/sleep waits for in-flight requests, then sleeps
  (d) /arcane/sleep answers 409 when requests outlive ?timeout=
  (e) a request that cannot get the lease in time gets 503 + Retry-After
  (f) GET /arcane/state and GET /v1/models never wake the engine
  (g) VLLM_IDLE_SECONDS=0 disables auto-sleep; > 0 auto-sleeps after idle
"""
import asyncio
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vllm_idle  # noqa: E402


class FakeEngine:
    def __init__(self):
        self.sleeping = False
        self.calls = []

    async def is_sleeping(self):
        return self.sleeping

    async def sleep(self, level=1, mode="abort"):
        self.calls.append(("sleep", level, mode))
        self.sleeping = True

    async def wake_up(self, tags=None):
        self.calls.append(("wake", tags))
        self.sleeping = False


class FakeLease:
    def __init__(self):
        self.held = True
        self.available = asyncio.Event()
        self.available.set()

    async def acquire(self):
        while not self.held:
            await self.available.wait()
            self.held = True

    def release(self):
        self.held = False


class App:
    """Minimal ASGI app: records that it ran; optionally blocks until released."""

    def __init__(self):
        self.ran = []
        self.gate = None

    async def __call__(self, scope, receive, send):
        self.ran.append(scope["path"])
        if self.gate is not None:
            await self.gate.wait()
        await send({"type": "http.response.start", "status": 200, "headers": []})
        await send({"type": "http.response.body", "body": b"ok"})


async def call(mw, method, path, query=b""):
    sent = []

    async def receive():
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        sent.append(message)

    scope = {"type": "http", "method": method, "path": path, "query_string": query}
    await mw(scope, receive, send)
    status = next(m["status"] for m in sent if m["type"] == "http.response.start")
    headers = dict(next(m["headers"] for m in sent if m["type"] == "http.response.start"))
    body = b"".join(m.get("body", b"") for m in sent if m["type"] == "http.response.body")
    return status, headers, body


def make(idle_seconds=0.0, lease_wait=1.0):
    app = App()
    mw = vllm_idle.IdleSleepMiddleware(app)
    engine, lease = FakeEngine(), FakeLease()
    mw.controller = vllm_idle.IdleController(engine, idle_seconds, lease=lease,
                                             lease_wait_seconds=lease_wait)
    return app, mw, engine, lease


class IdleMiddlewareTests(unittest.IsolatedAsyncioTestCase):
    async def test_a_sleep_releases_lease(self):
        _app, mw, engine, lease = make()
        status, _h, body = await call(mw, "POST", "/arcane/sleep")
        self.assertEqual(status, 200)
        self.assertTrue(json.loads(body)["slept"])
        self.assertEqual(engine.calls, [("sleep", 1, "wait")])
        self.assertFalse(lease.held)

    async def test_b_request_reacquires_and_wakes(self):
        app, mw, engine, lease = make()
        await call(mw, "POST", "/arcane/sleep")
        status, _h, _b = await call(mw, "POST", "/v1/chat/completions")
        self.assertEqual(status, 200)
        self.assertTrue(lease.held)
        self.assertFalse(engine.sleeping)
        self.assertEqual(engine.calls[-1], ("wake", None))
        self.assertEqual(app.ran, ["/v1/chat/completions"])

    async def test_c_sleep_waits_for_in_flight(self):
        app, mw, engine, _lease = make()
        app.gate = asyncio.Event()
        request = asyncio.create_task(call(mw, "POST", "/v1/chat/completions"))
        await asyncio.sleep(0.05)
        sleeper = asyncio.create_task(call(mw, "POST", "/arcane/sleep", b"timeout=5"))
        await asyncio.sleep(0.05)
        self.assertEqual(engine.calls, [])  # still serving
        app.gate.set()
        await request
        status, _h, _b = await sleeper
        self.assertEqual(status, 200)
        self.assertEqual(engine.calls, [("sleep", 1, "wait")])

    async def test_d_sleep_409_when_busy_past_timeout(self):
        app, mw, engine, lease = make()
        app.gate = asyncio.Event()
        request = asyncio.create_task(call(mw, "POST", "/v1/chat/completions"))
        await asyncio.sleep(0.05)
        status, _h, _b = await call(mw, "POST", "/arcane/sleep", b"timeout=0.1")
        self.assertEqual(status, 409)
        self.assertEqual(engine.calls, [])
        self.assertTrue(lease.held)
        app.gate.set()
        await request

    async def test_e_lease_timeout_gives_503(self):
        app, mw, _engine, lease = make(lease_wait=0.1)
        await call(mw, "POST", "/arcane/sleep")
        lease.available.clear()  # another unit / ComfyUI owns the GPU
        status, headers, _b = await call(mw, "POST", "/v1/chat/completions")
        self.assertEqual(status, 503)
        self.assertEqual(headers.get(b"retry-after"), b"5")
        self.assertEqual(app.ran, [])

    async def test_f_gets_never_wake(self):
        app, mw, engine, _lease = make()
        await call(mw, "POST", "/arcane/sleep")
        status, _h, body = await call(mw, "GET", "/arcane/state")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), {"sleeping": True, "active": 0, "lease_held": False})
        await call(mw, "GET", "/v1/models")
        self.assertTrue(engine.sleeping)
        self.assertEqual(app.ran, ["/v1/models"])

    async def test_g_idle_zero_disables_auto_sleep(self):
        _app, _mw, engine, _lease = make(idle_seconds=0.0)
        controller = _mw.controller
        controller.start()
        self.assertIsNone(controller.task)
        await asyncio.sleep(0.05)
        self.assertEqual(engine.calls, [])

        _app, mw, engine, lease = make(idle_seconds=0.05)
        mw.controller.start()
        try:
            await asyncio.sleep(0.3)
            self.assertEqual(engine.calls[0], ("sleep", 1, "wait"))
            self.assertFalse(lease.held)
        finally:
            await mw.controller.stop()


if __name__ == "__main__":
    unittest.main(verbosity=2)
