"""Five-second GPU idle sleep for the pinned vLLM 0.29 single API process.

Use --enable-sleep-mode --api-server-count 1
    --middleware vllm_idle.IdleSleepMiddleware.
No development HTTP routes are enabled. Weights remain in host RAM.
"""
import asyncio
import contextlib
import logging
import os
import time

LOG = logging.getLogger("vllm.idle")


class IdleController:
    def __init__(self, engine, idle_seconds=5.0, lease=None):
        if idle_seconds <= 0:
            raise ValueError("idle_seconds must be positive")
        self.engine = engine
        self.idle_seconds = idle_seconds
        self.active = 0
        self.last_finished = time.monotonic()
        self.lock = asyncio.Lock()
        self.changed = asyncio.Event()
        self.task = None
        self.uncertain = False
        self.lease = lease

    def start(self):
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
                await self.lease.acquire()
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

    async def watch(self):
        while True:
            delay = self.idle_seconds
            try:
                async with self.lock:
                    self.changed.clear()
                    idle_for = time.monotonic() - self.last_finished
                    if self.active == 0 and idle_for >= self.idle_seconds:
                        if self.uncertain or not await self.engine.is_sleeping():
                            started = time.monotonic()
                            self.uncertain = True
                            LOG.info("GPU sleep starting after %.3fs idle", idle_for)
                            # Drain background inference, if any, instead of aborting it.
                            await self.engine.sleep(level=1, mode="wait")
                            self.uncertain = False
                            LOG.info("GPU sleep completed in %.3fs", time.monotonic() - started)
                        if self.lease:
                            self.lease.release()
                    elif self.active == 0:
                        delay = self.idle_seconds - idle_for
            except Exception:
                LOG.exception("GPU idle sleep failed; will retry")
                delay = 1.0
            try:
                await asyncio.wait_for(self.changed.wait(), timeout=delay)
            except TimeoutError:
                pass


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

        # GET health/metrics/models polling and CPU tokenization must not keep
        # weights resident. Response retrieval may involve background inference.
        path = scope.get("path", "").rstrip("/")
        uses_engine = (
            scope["type"] == "websocket"
            or scope["type"] == "http" and (
                scope.get("method") == "POST" and path not in {"/tokenize", "/detokenize"}
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
            await send({"type": "http.response.start", "status": 503,
                        "headers": [(b"content-type", b"application/json"), (b"retry-after", b"5")]})
            return await send({"type": "http.response.body",
                               "body": b'{"error":{"message":"GPU wake unavailable; retry shortly","type":"server_error"}}'})
        try:
            # Raw ASGI wraps the entire streaming body, not just its headers.
            return await self.app(scope, receive, send)
        finally:
            await asyncio.shield(self.controller.leave())
