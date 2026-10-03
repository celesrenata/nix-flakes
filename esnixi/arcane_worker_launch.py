"""Run the Arcane Atlas Nextcloud queue worker against on-demand ComfyUI.

On esnixi, ComfyUI only starts when a connection reaches 127.0.0.1:28188, and
only once no vLLM unit holds the RTX 5090 lease. A job may therefore wait for
the GPU indefinitely. The upstream worker (shared NFS code, also used by the
4070 worker) uses 30 s HTTP timeouts and fails the job on any error, so this
wrapper wraps its acquire()/release():

- before a job: refuse fast (Busy) if another worker holds the shared lease,
  then block until ComfyUI is up and holds the GPU lease;
- during a job: keep the GPU lease alive so vLLM cannot take it between
  the job's CPU-only phases and stall the render past its deadline;
- after a job: stop the keepalive; ComfyUI unloads and releases the lease after
  its idle window, and systemd stops the container when connections stop.
"""
import importlib.util
import json
import os
import sys
import threading
import time
import urllib.error
import urllib.request

SCRIPT = os.environ.get(
    "AA_WORKER_SCRIPT",
    "/data/arcane-atlas/system/arcane-atlas-card-factory/scripts/nextcloud_queue_worker.py",
)
ACQUIRE_URL = os.environ["AA_COMFY_URL"].rstrip("/") + "/arcane/gpu/acquire"
REQUEST_TIMEOUT_SECONDS = 30
RETRY_SECONDS = 2.0
KEEPALIVE_SECONDS = 2.0


def log(message):
    print(f"[arcane-worker-launch] {message}", file=sys.stderr, flush=True)


def acquire_gpu_once():
    """POST the admission endpoint; True only when ComfyUI holds the lease."""
    request = urllib.request.Request(ACQUIRE_URL, data=b"", method="POST")
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            return json.loads(response.read() or b"{}").get("held") is True
    except urllib.error.HTTPError as error:
        error.close()
        return False
    except (OSError, ValueError):
        # Connection refused/reset, socket-activation timeout while ComfyUI is
        # still starting or waiting for vLLM, HTTP 503 (URLError is OSError).
        return False


def wait_for_gpu():
    started = time.monotonic()
    logged = False
    while not acquire_gpu_once():
        if not logged:
            log("waiting for ComfyUI and the RTX 5090 lease (vLLM may hold it)")
            logged = True
        time.sleep(RETRY_SECONDS)
    if logged:
        log(f"ComfyUI holds the GPU lease after {time.monotonic() - started:.1f}s")


class Keepalive:
    def __init__(self):
        self.stop_event = None
        self.thread = None

    def start(self):
        self.stop()
        stop_event = threading.Event()

        def run():
            while not stop_event.wait(KEEPALIVE_SECONDS):
                acquire_gpu_once()

        self.stop_event = stop_event
        self.thread = threading.Thread(target=run, name="comfy-gpu-keepalive", daemon=True)
        self.thread.start()

    def stop(self):
        if self.stop_event is not None:
            self.stop_event.set()
            self.thread.join(timeout=REQUEST_TIMEOUT_SECONDS + 5)
        self.stop_event = None
        self.thread = None


def load_worker():
    spec = importlib.util.spec_from_file_location("nextcloud_queue_worker", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def warm_worker_busy(worker):
    """Mirror the upstream acquire() preconditions without taking anything."""
    if worker.LEASE.exists() or (worker.WARM / "assignment.json").exists():
        return True
    try:
        state = json.loads((worker.WARM / "state.json").read_text())
    except (OSError, ValueError):
        return True
    return state.get("state") != "idle"


def main():
    worker = load_worker()
    upstream_acquire = worker.acquire
    upstream_release = worker.release
    keepalive = Keepalive()

    def acquire():
        # Check first so a busy shared lease never spins up ComfyUI or holds
        # the GPU while another worker owns the job store.
        if warm_worker_busy(worker):
            raise worker.Busy("Shared queue worker lease or warm worker is busy")
        wait_for_gpu()
        upstream_acquire()
        keepalive.start()

    def release():
        keepalive.stop()
        upstream_release()

    worker.acquire = acquire
    worker.release = release
    worker.main()


if __name__ == "__main__":
    main()
