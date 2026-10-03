"""ComfyUI 0.36.0 admission and idle unloading for a shared desktop GPU."""
import asyncio
import contextlib
import gc
import logging
import os
import time

from aiohttp import web
import torch
import comfy.model_management as mm
from server import PromptServer
from arcane_gpu import GPULease

NODE_CLASS_MAPPINGS = {}
LOG = logging.getLogger("arcane.gpu")
# Bounded server-side wait for /arcane/gpu/acquire; the caller retries, so a
# long vLLM tenancy never leaves orphaned waiters behind.
ACQUIRE_WAIT_SECONDS = 20


class Admission:
    def __init__(self, server):
        self.server = server
        self.lease = GPULease.from_environment()
        if self.lease is None:
            raise RuntimeError("Shared GPU worker requires ARCANE_GPU_LOCK")
        self.lock = asyncio.Lock()
        self.last_activity = time.monotonic()
        self.task = None
        self.idle_unload_seconds = float(os.environ.get("AA_COMFY_IDLE_UNLOAD_SECONDS", "5"))
        queue = server.prompt_queue
        original_get = queue.get

        def gpu_get(timeout=None):
            # Wait in the native execution thread. HTTP submissions return
            # immediately and queued jobs remain cancellable while vLLM owns
            # the GPU. Do not claim a running job before ownership is granted.
            with queue.not_empty:
                while not queue.queue:
                    queue.not_empty.wait(timeout=timeout)
                    if timeout is not None and not queue.queue:
                        return None
            self.lease.acquire_blocking()
            # The job may have been deleted while we waited for ownership.
            return original_get(timeout=0)

        queue.get = gpu_get

    async def start(self, app):
        self.last_activity = time.monotonic()
        self.task = asyncio.create_task(self.watch(), name="comfy-gpu-admission")

    async def stop(self, app):
        if self.task:
            self.task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self.task
        # Keep an owned descriptor open until process exit. Cleanup has not
        # necessarily finished releasing the CUDA context at this point.

    @web.middleware
    async def middleware(self, request, handler):
        if request.method == "POST" and request.path.rstrip("/") == "/prompt":
            async with self.lock:
                try:
                    return await handler(request)
                finally:
                    self.last_activity = time.monotonic()
        return await handler(request)

    async def acquire_route(self, request):
        """Take (or keep) the GPU lease for a queue-worker job.

        The esnixi queue worker calls this before a job and as a keepalive
        during it, so a job owns the GPU end to end instead of losing it to
        vLLM during CPU-only phases (uploads, compositing) and then stalling
        past its render deadline.
        """
        async with self.lock:
            try:
                await asyncio.wait_for(self.lease.acquire(), ACQUIRE_WAIT_SECONDS)
            except TimeoutError:
                return web.json_response({"held": False}, status=503, headers={"Retry-After": "2"})
            self.last_activity = time.monotonic()
        return web.json_response({"held": True})

    async def watch(self):
        while True:
            await asyncio.sleep(.1)
            try:
                async with self.lock:
                    if not self.lease.held:
                        continue
                    q = self.server.prompt_queue
                    if q.get_tasks_remaining():
                        self.last_activity = time.monotonic()
                        continue
                    if time.monotonic() - self.last_activity < self.idle_unload_seconds:
                        continue
                    # Ask the native execution thread to unload, reset its
                    # output cache and collect CUDA tensors before handoff.
                    q.set_flag("unload_models", True)
                    q.set_flag("free_memory", True)
                    deadline = time.monotonic() + 30
                    while True:
                        await asyncio.sleep(.1)
                        if (not q.get_flags(reset=False)
                                and not mm.current_loaded_models
                                and torch.cuda.memory_reserved() < 128 * 2**20):
                            break
                        if time.monotonic() >= deadline:
                            raise RuntimeError("ComfyUI did not release its model/cache memory; retaining GPU lease")
                    # Comfy's queue flags release CUDA tensors, but Python-side
                    # model wrappers can otherwise keep tens of GiB resident.
                    # Use only APIs present in the running Comfy version.
                    for name in ("cleanup_models_gc", "unload_all_models"):
                        cleanup = getattr(mm, name, None)
                        if callable(cleanup):
                            cleanup()
                    gc.collect()
                    if hasattr(torch.cuda, "empty_cache"):
                        torch.cuda.empty_cache()
                    if hasattr(torch.cuda, "ipc_collect"):
                        torch.cuda.ipc_collect()
                    self.lease.release()
                    LOG.info("ComfyUI released GPU and host model memory after %.1fs idle", self.idle_unload_seconds)
            except Exception:
                LOG.exception("Shared GPU unload failed; retaining ownership")
                await asyncio.sleep(1)


admission = Admission(PromptServer.instance)
PromptServer.instance.app.middlewares.append(admission.middleware)
PromptServer.instance.routes.post("/arcane/gpu/acquire")(admission.acquire_route)
PromptServer.instance.app.on_startup.append(admission.start)
PromptServer.instance.app.on_cleanup.append(admission.stop)
