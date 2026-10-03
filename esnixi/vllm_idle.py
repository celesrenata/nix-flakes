"""GPU sleep/wake controller for a single vLLM API process (sleep mode, level 1).

Use --enable-sleep-mode --api-server-count 1
    --middleware vllm_idle.IdleSleepMiddleware.
No development HTTP routes are enabled. Weights remain in pinned host RAM while
asleep; level 1 discards the GPU KV cache.

The shared RTX 5090 lease (arcane_gpu.GPULease, inherited from gpu_launch.py) is
released after every sleep and re-acquired before every wake, so two co-resident
vLLM units (and ComfyUI) hand the GPU over without restarting anything.

Environment:
  VLLM_IDLE_SECONDS        auto-sleep after this much idle; 0 disables auto-sleep
                           (the unit then sleeps only on POST /arcane/sleep).
  VLLM_LEASE_WAIT_SECONDS  how long a request waits for the GPU lease before a
                           503 + Retry-After (default 60).

Local control endpoints (the backend binds 127.0.0.1; never forwarded by the switcher):
  POST /arcane/sleep  drain in-flight requests, sleep, release the lease.
                      200 {"slept": true, "seconds": s}; 409 if requests stay in
                      flight past ?timeout= (default 30 s).
  GET  /arcane/state  {"sleeping", "active", "lease_held"}; never wakes the engine.
"""
import asyncio
import contextlib
import json
import logging
import os
import time
from urllib.parse import parse_qs

LOG = logging.getLogger("vllm.idle")
SLEEP_PATH = "/arcane/sleep"
STATE_PATH = "/arcane/state"


class IdleController:
    def __init__(self, engine, idle_seconds=5.0, lease=None, lease_wait_seconds=60.0):
        if idle_seconds < 0:
            raise ValueError("idle_seconds must not be negative")
        self.engine = engine
        self.idle_seconds = idle_seconds
        self.lease_wait_seconds = lease_wait_seconds
        self.active = 0
        self.last_finished = time.monotonic()
        self.lock = asyncio.Lock()
        self.changed = asyncio.Event()
        self.task = None
        self.uncertain = False
        self.lease = lease

    def start(self):
        if self.idle_seconds == 0:
            LOG.info("GPU idle sleep disabled; sleeping only on POST %s", SLEEP_PATH)
            return
        self.task = asyncio.create_task(self.watch(), name="vllm-idle-sleep")
        LOG.info("GPU idle sleep enabled: %.1f seconds, level=1, mode=wait", self.idle_seconds)

    async def stop(self):
        if self.task is not None:
            self.task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self.task

    async def enter(self):
        # This lock covers admission and the complete sleep/wake transition.
        # A request arriving during a sleep waits, then wakes before inference.
        async with self.lock:
            if self.lease:
                # Blocks while the other vLLM unit or ComfyUI owns the GPU.
                await asyncio.wait_for(self.lease.acquire(), self.lease_wait_seconds)
            if self.uncertain or await self.engine.is_sleeping():
                started = time.monotonic()
                self.uncertain = True
                await self.engine.wake_up()
                self.uncertain = False
                LOG.info("GPU wake completed in %.3fs", time.monotonic() - started)
            self.active += 1
            self.changed.set()

    async def leave(self):
        async with self.lock:
            self.active -= 1
            self.last_finished = time.monotonic()
            self.changed.set()

    async def _sleep_locked(self, reason):
        """Sleep (if awake) and release the lease. Caller holds self.lock."""
        started = time.monotonic()
        if self.uncertain or not await self.engine.is_sleeping():
            self.uncertain = True
            LOG.info("GPU sleep starting (%s)", reason)
            # Drain background inference, if any, instead of aborting it.
            await self.engine.sleep(level=1, mode="wait")
            self.uncertain = False
            LOG.info("GPU sleep completed in %.3fs", time.monotonic() - started)
        if self.lease:
            self.lease.release()
        return time.monotonic() - started

    async def sleep_now(self, timeout=30.0):
        """Sleep as soon as no request is in flight; None if still busy at timeout."""
        deadline = time.monotonic() + timeout
        while True:
            async with self.lock:
                if self.active == 0:
                    return await self._sleep_locked("requested")
                self.changed.clear()
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return None
            # leave() needs the lock, so wait for it outside the lock.
            with contextlib.suppress(TimeoutError):
                await asyncio.wait_for(self.changed.wait(), timeout=min(remaining, 1.0))

    async def state(self):
        return {
            "sleeping": bool(await self.engine.is_sleeping()),
            "active": self.active,
            "lease_held": bool(self.lease.held) if self.lease else None,
        }

    async def watch(self):
        while True:
            delay = self.idle_seconds
            try:
                async with self.lock:
                    self.changed.clear()
                    idle_for = time.monotonic() - self.last_finished
                    if self.active == 0 and idle_for >= self.idle_seconds:
                        await self._sleep_locked(f"idle {idle_for:.3f}s")
                    elif self.active == 0:
                        delay = self.idle_seconds - idle_for
            except Exception:
                LOG.exception("GPU idle sleep failed; will retry")
                delay = 1.0
            try:
                await asyncio.wait_for(self.changed.wait(), timeout=delay)
            except TimeoutError:
                pass


async def _send_json(send, status, payload, extra_headers=()):
    body = json.dumps(payload).encode()
    headers = [(b"content-type", b"application/json"), *extra_headers]
    await send({"type": "http.response.start", "status": status, "headers": headers})
    await send({"type": "http.response.body", "body": body})


class IdleSleepMiddleware:
    def __init__(self, app):
        self.app = app
        self.controller = None

    async def __call__(self, scope, receive, send):
        if scope["type"] == "lifespan":
            async def lifespan_send(message):
                if message["type"] == "lifespan.startup.complete":
                    lease = None
                    if os.environ.get("ARCANE_GPU_LOCK"):
                        from arcane_gpu import GPULease
                        lease = GPULease.from_environment()
                    self.controller = IdleController(
                        scope["app"].state.engine_client,
                        float(os.environ.get("VLLM_IDLE_SECONDS", "5")),
                        lease=lease,
                        lease_wait_seconds=float(os.environ.get("VLLM_LEASE_WAIT_SECONDS", "60")),
                    )
                    self.controller.start()
                await send(message)

            async def lifespan_receive():
                message = await receive()
                if message["type"] == "lifespan.shutdown" and self.controller:
                    await self.controller.stop()
                return message

            try:
                return await self.app(scope, lifespan_receive, lifespan_send)
            finally:
                if self.controller:
                    await self.controller.stop()

        path = scope.get("path", "").rstrip("/")
        method = scope.get("method")
        if scope["type"] == "http" and path in (SLEEP_PATH, STATE_PATH):
            return await self.control(scope, send, path, method)

        # GET health/metrics/models polling and CPU tokenization must not keep
        # weights resident. Response retrieval may involve background inference.
        uses_engine = (
            scope["type"] == "websocket"
            or scope["type"] == "http" and (
                method == "POST" and path not in {"/tokenize", "/detokenize"}
                or path.startswith("/v1/responses/")
            )
        )
        if not uses_engine or self.controller is None:
            return await self.app(scope, receive, send)

        try:
            await self.controller.enter()
        except Exception:
            LOG.exception("GPU wake failed")
            if scope["type"] == "websocket":
                return await send({"type": "websocket.close", "code": 1013})
            return await _send_json(
                send, 503,
                {"error": {"message": "GPU wake unavailable; retry shortly", "type": "server_error"}},
                [(b"retry-after", b"5")])
        try:
            # Raw ASGI wraps the entire streaming body, not just its headers.
            return await self.app(scope, receive, send)
        finally:
            await asyncio.shield(self.controller.leave())

    async def control(self, scope, send, path, method):
        if self.controller is None:
            return await _send_json(send, 503, {"error": "starting"}, [(b"retry-after", b"2")])
        if path == STATE_PATH and method == "GET":
            return await _send_json(send, 200, await self.controller.state())
        if path == SLEEP_PATH and method == "POST":
            query = parse_qs(scope.get("query_string", b"").decode())
            try:
                timeout = float(query.get("timeout", ["30"])[0])
            except ValueError:
                return await _send_json(send, 400, {"error": "invalid timeout"})
            try:
                seconds = await self.controller.sleep_now(timeout=max(0.0, min(timeout, 300.0)))
            except Exception:
                LOG.exception("GPU sleep request failed")
                return await _send_json(send, 500, {"error": "sleep failed"})
            if seconds is None:
                return await _send_json(send, 409, {"error": "requests still in flight"})
            return await _send_json(send, 200, {"slept": True, "seconds": round(seconds, 3)})
        return await _send_json(send, 405, {"error": "method not allowed"})
