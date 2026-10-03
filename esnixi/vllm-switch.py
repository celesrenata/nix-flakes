#!/usr/bin/env python3
"""Authenticated, serialized OpenAI-compatible gateway for the esnixi RTX 5090."""

from __future__ import annotations

import hmac
import json
import os
import subprocess
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


SYSTEMCTL = os.environ["SYSTEMCTL"]
SUDO = os.environ["SUDO"]
LOCK_WAIT_SECONDS = 3
MODEL_READY_SECONDS = 540
# How long a sleep request may wait for the old unit's in-flight requests to drain
# before the switcher falls back to a full stop.
SLEEP_DRAIN_SECONDS = 30


def _env_seconds(name: str, default: float) -> float:
    try:
        value = float(os.environ.get(name, default))
    except ValueError:
        return default
    return value if value >= 0 else default


# Minimum residency (hysteresis): an idle model used within this window is
# treated as busy for requests that need a DIFFERENT unit (fast 409 ->
# next OmniRoute target) instead of being evicted. 0 disables.
RESIDENCY_SECONDS = _env_seconds("VLLM_SWITCH_RESIDENCY_SECONDS", 90.0)
# Settle delay after the other unit reaches inactive, so the driver finishes
# reclaiming VRAM before the target's cudaMalloc (the flock is the real guard).
DRAIN_SETTLE_SECONDS = 2
MAX_REQUEST_BYTES = 32 * 1024 * 1024
DEFAULT_MAX_COMPLETION_TOKENS = 16384
BALANCED_MODEL_ID = "qwen3.8-27b-nvfp4-balanced"
BALANCED_THINKING_BUDGET = 2048
FULL_THINKING_BUDGET = 8192

MODELS = {
    # COUPLED to vllm.service in esnixi/vllm.nix: "context" == --max-model-len
    # (otherwise the readiness poll never matches), "max_requests" ==
    # --max-num-seqs and "port" == --port. Both coder aliases share one engine and
    # the single active_requests counter, so they must carry the same max_requests.
    # A unit test asserts this (test_vllm_switch.py).
    "qwen3.8-27b-nvfp4": {
        "unit": "vllm.service",
        "port": 8010,
        "served": "qwen3.8-27b-nvfp4",
        "hf_id": "nvidia/Qwen3.8-27B-NVFP4",
        "context": 131072,
        "max_requests": 4,
    },
    BALANCED_MODEL_ID: {
        "unit": "vllm.service",
        "port": 8010,
        "served": "qwen3.8-27b-nvfp4",
        "hf_id": "nvidia/Qwen3.8-27B-NVFP4",
        "context": 131072,
        "max_requests": 4,
    },
    "qwen3.5-9b-nvfp4-reader": {
        "unit": "vllm-reader.service",
        # COUPLED to the reader unit's --port in esnixi/vllm.nix.
        "port": 8012,
        "served": "qwen3.5-9b-nvfp4-reader",
        "hf_id": "AxionML/Qwen3.5-9B-NVFP4",
        # COUPLED to the reader unit's served --max-model-len in esnixi/vllm.nix.
        # If these two ever disagree, select_model's readiness poll (which requires
        # max_model_len == context) never matches, burns MODEL_READY_SECONDS, then
        # 409s to the next tier forever. Change BOTH together. A unit test asserts
        # this equality (test_vllm_switch.py).
        "context": 65536,
        "max_requests": 8,
    },
}
ALIASES = {}
for model_id, model in MODELS.items():
    for alias in (model_id, f"vllm/{model_id}"):
        ALIASES[alias] = model_id
ALIASES["nvidia/Qwen3.8-27B-NVFP4"] = "qwen3.8-27b-nvfp4"
ALIASES["vllm/nvidia/Qwen3.8-27B-NVFP4"] = "qwen3.8-27b-nvfp4"
BALANCED_ALIASES = {BALANCED_MODEL_ID, f"vllm/{BALANCED_MODEL_ID}"}
switch_condition = threading.Condition()
active_model: str | None = None
active_requests = 0
switching = False
last_activity: float | None = None  # monotonic; last acquire/release on active_model. Guarded by switch_condition.


def residency_remaining(now: float) -> float:
    """Seconds the idle active model is still protected; 0 when swappable. Hold switch_condition."""
    if active_model is None or last_activity is None or RESIDENCY_SECONDS <= 0:
        return 0.0
    return max(0.0, last_activity + RESIDENCY_SECONDS - now)


def backend_url(model_id: str) -> str:
    return f"http://127.0.0.1:{MODELS[model_id]['port']}"


def unit_port(unit: str) -> int:
    return next(m["port"] for m in MODELS.values() if m["unit"] == unit)


def read_token() -> str:
    credential_dir = os.environ["CREDENTIALS_DIRECTORY"]
    with open(os.path.join(credential_dir, "bearer-token"), encoding="utf-8") as f:
        token = f.read().strip()
    if len(token) < 32:
        raise RuntimeError("switch gateway credential is missing or too short")
    return token


TOKEN = read_token()


def normalize_chat_system_messages(payload: dict) -> bool:
    """Keep all system instructions, but put one merged message first for Qwen.

    Qwen's vLLM chat template rejects a system role after any other role.
    OmniRoute can insert another system message while compressing a long chat.
    """
    messages = payload.get("messages")
    if not isinstance(messages, list):
        return False
    system_messages = [
        message for message in messages
        if isinstance(message, dict) and message.get("role") == "system"
    ]
    if not system_messages or (
        len(system_messages) == 1 and messages[0] is system_messages[0]
    ):
        return False

    def system_text(message: dict) -> str:
        content = message.get("content", "")
        if isinstance(content, str):
            return content
        if isinstance(content, list) and all(
            isinstance(part, dict)
            and part.get("type") == "text"
            and isinstance(part.get("text"), str)
            for part in content
        ):
            return "\n".join(part["text"] for part in content)
        raise ValueError("unsupported system message content")

    merged = dict(system_messages[0])
    merged["content"] = "\n\n".join(system_text(message) for message in system_messages)
    payload["messages"] = [merged] + [
        message for message in messages
        if not (isinstance(message, dict) and message.get("role") == "system")
    ]
    return True


def normalize_qwen_reasoning(payload: dict, requested: str) -> None:
    """Bound implicit thinking while honoring explicit budgets and no-think."""
    balanced = requested in BALANCED_ALIASES
    supplied_effort = payload.get("reasoning_effort")
    effort = supplied_effort
    if effort in {"high", "xhigh", "max", "ultra"}:
        # The installed template accepts low/medium/xhigh, but not high.
        effort = "medium" if balanced else "xhigh"
    elif effort is None:
        effort = "low" if balanced else "medium"

    output_limit = payload.get(
        "max_completion_tokens", payload.get("max_tokens", DEFAULT_MAX_COMPLETION_TOKENS)
    )
    if not isinstance(output_limit, int) or output_limit <= 0:
        output_limit = DEFAULT_MAX_COMPLETION_TOKENS
    if supplied_effort is None and "thinking_token_budget" not in payload and output_limit <= 512:
        effort = "none"
    payload["reasoning_effort"] = effort

    if effort != "none" and "thinking_token_budget" not in payload:
        budget = BALANCED_THINKING_BUDGET if balanced else FULL_THINKING_BUDGET
        if balanced and effort in {"medium", "xhigh"}:
            budget = 4096
        payload["thinking_token_budget"] = min(budget, output_limit // 2)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    server_version = "vllm-switch/1"

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def authorized(self) -> bool:
        prefix = "Bearer "
        header = self.headers.get("Authorization", "")
        supplied = header[len(prefix) :] if header.startswith(prefix) else ""
        return hmac.compare_digest(supplied.encode(), TOKEN.encode())

    def json_response(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        if path == "/healthz":
            self.json_response(200, {"status": "ok"})
            return
        if not self.authorized():
            self.json_response(401, {"error": {"message": "unauthorized"}})
            return
        if path != "/v1/models":
            self.json_response(404, {"error": {"message": "not found"}})
            return
        self.json_response(
            200,
            {
                "object": "list",
                "data": [
                    {
                        "id": model_id,
                        "object": "model",
                        "created": 0,
                        "owned_by": "nvidia",
                        "root": model["hf_id"],
                        "context_length": model["context"],
                        "max_input_tokens": model["context"] - 32768,
                        "max_output_tokens": 32768,
                    }
                    for model_id, model in MODELS.items()
                ],
            },
        )
    def do_POST(self) -> None:
        path = urlsplit(self.path).path
        if not self.authorized():
            self.json_response(401, {"error": {"message": "unauthorized"}})
            return
        if path not in {
            "/v1/chat/completions",
            "/v1/completions",
            "/v1/responses",
        }:
            self.json_response(404, {"error": {"message": "unsupported endpoint"}})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.json_response(400, {"error": {"message": "invalid content length"}})
            return
        if length <= 0 or length > MAX_REQUEST_BYTES:
            self.json_response(413, {"error": {"message": "request body too large or empty"}})
            return

        try:
            payload = json.loads(self.rfile.read(length))
            requested = payload.get("model") if isinstance(payload, dict) else None
            model_id = ALIASES.get(requested)
            if model_id is None:
                self.json_response(400, {"error": {"message": "unknown 5090 model"}})
                return
            payload["model"] = MODELS[model_id]["served"]
            if path == "/v1/chat/completions" and not any(
                key in payload for key in ("max_tokens", "max_completion_tokens")
            ):
                payload["max_tokens"] = DEFAULT_MAX_COMPLETION_TOKENS
            if path == "/v1/chat/completions":
                normalize_qwen_reasoning(payload, requested)
                normalize_chat_system_messages(payload)
            body = json.dumps(payload, separators=(",", ":")).encode()
        except (UnicodeDecodeError, json.JSONDecodeError, AttributeError, TypeError, ValueError):
            self.json_response(400, {"error": {"message": "invalid JSON request"}})
            return

        if not self.acquire_model(model_id):
            self.json_response(
                409,
                {"error": {"message": "RTX 5090 is busy; use the next OmniRoute fallback"}},
            )
            return
        try:
            self.proxy(path, body, model_id)
        finally:
            self.release_model()

    def acquire_model(self, model_id: str) -> bool:
        """Serialize both logical aliases against the one loaded model."""
        global active_model, active_requests, switching, last_activity
        deadline = time.monotonic() + LOCK_WAIT_SECONDS
        with switch_condition:
            while True:
                hold = 0.0
                if not switching and active_model is not None and MODELS[active_model]["unit"] == MODELS[model_id]["unit"]:
                    if active_requests < MODELS[model_id]["max_requests"]:
                        last_activity = time.monotonic()
                        active_requests += 1
                        return True
                elif not switching and active_requests == 0:
                    # Hysteresis: an idle model used within RESIDENCY_SECONDS is
                    # treated as busy for a different unit (-> 409, next target).
                    hold = residency_remaining(time.monotonic())
                    if hold <= 0:
                        switching = True
                        active_model = None
                        last_activity = None
                        break

                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return False
                # Nothing notifies when the residency window expires, so wake
                # at its end if that comes before the lock-wait deadline.
                switch_condition.wait(min(remaining, hold) if hold > 0 else remaining)

        ready = False
        try:
            ready = self.select_model(model_id)
            return ready
        finally:
            with switch_condition:
                active_model = model_id if ready else None
                last_activity = time.monotonic() if ready else None
                switching = False
                if ready:
                    active_requests += 1
                switch_condition.notify_all()

    def release_model(self) -> None:
        global active_requests, last_activity
        with switch_condition:
            if active_requests > 0:
                active_requests -= 1
            if active_model is not None:
                last_activity = time.monotonic()
            # Idle readers put themselves to sleep (vllm_idle.py VLLM_IDLE_SECONDS),
            # so the switcher no longer stops them.
            switch_condition.notify_all()

    def other_units(self, target_unit: str) -> list[str]:
        """Every distinct vLLM unit in MODELS that is not the target unit."""
        units = {m["unit"] for m in MODELS.values()}
        return [u for u in units if u != target_unit]

    def unit_state(self, unit: str) -> tuple[str, str]:
        """Return (ActiveState, SubState) for a unit via one systemctl show."""
        try:
            out = subprocess.check_output(
                [SYSTEMCTL, "show", "--value",
                 "--property=ActiveState", "--property=SubState", unit],
                text=True, timeout=5).splitlines()
        except (subprocess.SubprocessError, OSError):
            return ("", "")
        active = out[0].strip() if len(out) > 0 else ""
        sub = out[1].strip() if len(out) > 1 else ""
        return (active, sub)

    def stop_and_drain(self, unit: str, deadline: float) -> bool:
        """Stop `unit` and wait until it is inactive/dead (VRAM returned).

        Bounded by `deadline` (monotonic). Returns True if the unit reached
        inactive within the deadline. nvidia-smi is NOT on this unit's PATH, so
        drain is detected via the unit's own ActiveState/SubState.
        """
        try:
            subprocess.run(
                [SUDO, "-n", SYSTEMCTL, "stop", unit],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=120,
            )
        except (subprocess.SubprocessError, OSError):
            return False
        while time.monotonic() < deadline:
            active, sub = self.unit_state(unit)
            if active in ("inactive", "failed") and sub in ("dead", "failed", ""):
                # Give the driver a moment to finish reclaiming VRAM.
                time.sleep(DRAIN_SETTLE_SECONDS)
                return True
            time.sleep(0.5)
        return False

    def sleep_unit(self, unit: str, deadline: float) -> bool:
        """Ask a running unit to sleep (weights to host RAM) and release the GPU lease.

        Retries while the unit is busy or not yet serving, up to SLEEP_DRAIN_SECONDS.
        Returns False so the caller can fall back to a full stop.
        """
        url = f"http://127.0.0.1:{unit_port(unit)}/arcane/sleep?timeout=10"
        give_up = min(deadline, time.monotonic() + SLEEP_DRAIN_SECONDS)
        while time.monotonic() < give_up:
            request = urllib.request.Request(url, data=b"", method="POST")
            try:
                with urllib.request.urlopen(request, timeout=120) as response:
                    if response.status == 200:
                        return True
            except urllib.error.HTTPError as error:
                error.close()
                if error.code not in (409, 503):
                    return False
            except (urllib.error.URLError, OSError):
                pass
            time.sleep(0.5)
        return False

    def unit_running(self, unit: str) -> bool:
        active, _sub = self.unit_state(unit)
        return active == "active"

    def select_model(self, model_id: str) -> bool:
        selected = MODELS[model_id]
        deadline = time.monotonic() + MODEL_READY_SECONDS
        # Single tenancy authority: every OTHER vLLM unit must give up the GPU
        # BEFORE the target runs. Running units sleep (weights stay in host RAM,
        # lease released); a unit that cannot sleep is stopped and drained. Only
        # ever reached with active_requests == 0 and the residency window expired
        # (acquire_model gate), so no generation is in flight.
        for other in self.other_units(selected["unit"]):
            active, _sub = self.unit_state(other)
            if active in ("inactive", "failed", ""):
                continue
            if active == "active" and self.sleep_unit(other, deadline):
                continue
            if not self.stop_and_drain(other, deadline):
                return False
        # Warm path: a running (possibly sleeping) target is ready as soon as it
        # answers /v1/models; its middleware takes the lease and wakes it on the
        # first engine request.
        if self.unit_running(selected["unit"]) and self.wait_ready(model_id, deadline, -1):
            return True
        # Clear any stale `failed` state on the target so its own is-failed guard
        # (below) does not refuse to start a deliberately-stopped unit.
        try:
            subprocess.run(
                [SUDO, "-n", SYSTEMCTL, "reset-failed", selected["unit"]],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
            )
        except (subprocess.SubprocessError, OSError):
            pass
        # A layout that exhausted VRAM must not evict the working model again
        # until an operator clears its failed state after changing GPU capacity.
        if subprocess.run([SYSTEMCTL, "is-failed", "--quiet", selected["unit"]],
                          check=False).returncode == 0:
            return False
        try:
            restarts_before = int(subprocess.check_output(
                [SYSTEMCTL, "show", "--value", "--property=NRestarts", selected["unit"]],
                text=True, timeout=5).strip())
        except (ValueError, subprocess.SubprocessError):
            restarts_before = -1
        try:
            subprocess.run(
                [SUDO, "-n", SYSTEMCTL, "start", selected["unit"]],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=120,
            )
        except (subprocess.SubprocessError, OSError):
            return False
        return self.wait_ready(model_id, deadline, restarts_before)

    def wait_ready(self, model_id: str, deadline: float, restarts_before: int) -> bool:
        """Poll the target's /v1/models until it serves the expected model/context.

        restarts_before == -1 is the warm path (no start issued): give up as soon
        as the unit is no longer running so the caller can cold-start it.
        """
        selected = MODELS[model_id]
        while time.monotonic() < deadline:
            if restarts_before == -1 and not self.unit_running(selected["unit"]):
                return False
            request = urllib.request.Request(f"{backend_url(model_id)}/v1/models")
            try:
                with urllib.request.urlopen(request, timeout=3) as response:
                    models = json.loads(response.read())
                    if any(
                        item.get("id") == selected["served"]
                        and item.get("max_model_len") == selected["context"]
                        for item in models.get("data", [])
                    ):
                        return True
            except (urllib.error.URLError, OSError, json.JSONDecodeError, ValueError):
                pass
            # An incompatible layout can fail after systemctl start returns.
            # Return promptly so OmniRoute can try the next target.
            if subprocess.run([SYSTEMCTL, "is-failed", "--quiet", selected["unit"]],
                              check=False).returncode == 0:
                return False
            if restarts_before >= 0:
                try:
                    restarts_now = int(subprocess.check_output(
                        [SYSTEMCTL, "show", "--value", "--property=NRestarts", selected["unit"]],
                        text=True, timeout=5).strip())
                    if restarts_now > restarts_before:
                        return False
                except (ValueError, subprocess.SubprocessError):
                    pass
            time.sleep(2)
        return False

    def proxy(self, path: str, body: bytes, model_id: str) -> None:
        headers = {
            "Content-Type": self.headers.get("Content-Type", "application/json"),
            "Accept": self.headers.get("Accept", "text/event-stream, application/json"),
            "Accept-Encoding": "identity",
        }
        request = urllib.request.Request(f"{backend_url(model_id)}{path}", data=body, headers=headers, method="POST")
        try:
            upstream = urllib.request.urlopen(request, timeout=900)
        except urllib.error.HTTPError as error:
            upstream = error
        except (urllib.error.URLError, TimeoutError, OSError):
            self.json_response(502, {"error": {"message": "vLLM backend connection failed"}})
            return

        with upstream:
            self.send_response(upstream.status)
            for name, value in upstream.headers.items():
                if name.lower() not in {
                    "connection",
                    "content-length",
                    "keep-alive",
                    "proxy-authenticate",
                    "proxy-authorization",
                    "te",
                    "trailer",
                    "transfer-encoding",
                    "upgrade",
                }:
                    self.send_header(name, value)
            self.send_header("Connection", "close")
            self.end_headers()
            while True:
                # read(n) waits for n bytes or EOF; SSE responses may never
                # reach that size before the client readiness deadline.
                chunk = upstream.read1(64 * 1024)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    Server(("127.0.0.1", 8011), Handler).serve_forever()
