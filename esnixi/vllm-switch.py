#!/usr/bin/env python3
"""Authenticated, serialized OpenAI-compatible gateway for the esnixi RTX 5090.

Fail-safe tenancy (one model awake on the 5090 at a time):
  * Selecting the reader sleeps the coder; selecting the coder STOPS the reader,
    because the coder's KV budget leaves no room for the reader's sleep residual.
  * The 27B coder (PRIMARY_MODEL) is the protected default; the reader is secondary.
    A reader request never evicts the coder while it has requests in flight or is
    inside CODER_RESIDENCY_SECONDS of its last use (409 to the next OmniRoute tier).
  * A failed switch (unit failed, NRestarts rose, readiness timeout, eviction
    failure) stops the failed target, restores the previous model and answers 409.
  * A per-unit circuit breaker then rejects that target immediately (no sleep, no
    stop of the active model) with exponential backoff. A failed coder start
    (unit failed / restarted / start error) is first retried CODER_FAST_RETRIES
    times, CODER_FAST_RETRY_DELAY_SECONDS apart; if all fail the coder is stopped
    (no systemd crash loop) and its breaker records ONE failure.
  * A watchdog thread makes the coder ready again when nothing is ready.
  * Every sleep/stop/start/readiness wait is bounded; the switch lock is never held
    across subprocess or HTTP calls, so concurrent requests get fast 409s.
Known limitation: the switch runs in the request thread, so a successful reader cold
start (~110 s) can exceed OmniRoute's client timeout for the request that triggered
it; follow-up requests succeed.
"""

from __future__ import annotations

import hmac
import json
import logging
import math
import os
import subprocess
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit


LOG = logging.getLogger("vllm.switch")

SYSTEMCTL = os.environ["SYSTEMCTL"]
SUDO = os.environ["SUDO"]
LOCK_WAIT_SECONDS = 3


def _env_seconds(name: str, default: float) -> float:
    try:
        value = float(os.environ.get(name, default))
    except ValueError:
        return default
    return value if value >= 0 else default


# Total budget for asking the old unit to sleep (retries while it drains) before
# the switcher falls back to a full stop.
SLEEP_DRAIN_SECONDS = _env_seconds("VLLM_SWITCH_SLEEP_SECONDS", 90.0)
# Budget for `systemctl stop` + drain; above TimeoutStopSec (120 s) so systemd's
# SIGKILL lands inside it.
STOP_SECONDS = _env_seconds("VLLM_SWITCH_STOP_SECONDS", 150.0)
# Readiness budget for one switch (cold start worst case: coder 174 s, reader 110 s).
START_SECONDS = _env_seconds("VLLM_SWITCH_START_SECONDS", 300.0)
# Minimum residency (hysteresis) for an idle NON-primary model: requests for a
# different unit within the window get a fast 409 instead of evicting it. 0 lets
# the coder reclaim the GPU from an idle reader immediately.
RESIDENCY_SECONDS = _env_seconds("VLLM_SWITCH_RESIDENCY_SECONDS", 90.0)
# Residency protecting the primary coder from eviction by a reader request.
CODER_RESIDENCY_SECONDS = _env_seconds("VLLM_SWITCH_CODER_RESIDENCY_SECONDS", 90.0)
# Circuit breaker: first backoff after a failed switch, doubling up to the max.
BACKOFF_SECONDS = _env_seconds("VLLM_SWITCH_BACKOFF_SECONDS", 300.0)
BACKOFF_MAX_SECONDS = _env_seconds("VLLM_SWITCH_BACKOFF_MAX_SECONDS", 1800.0)
# Immediate retries of a failed primary-coder start before its breaker opens.
CODER_FAST_RETRIES = int(_env_seconds("VLLM_SWITCH_CODER_FAST_RETRIES", 2.0))
# Pause between coder fast retries (after the failed attempt is stopped).
CODER_FAST_RETRY_DELAY_SECONDS = _env_seconds("VLLM_SWITCH_CODER_FAST_RETRY_DELAY_SECONDS", 15.0)
# Watchdog: make the coder ready after this long with no ready model.
WATCHDOG_SECONDS = _env_seconds("VLLM_SWITCH_WATCHDOG_SECONDS", 60.0)
WATCHDOG_INTERVAL_SECONDS = 5.0
SUBPROCESS_TIMEOUT_SECONDS = 10
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
        "context": 147456,
        "max_requests": 3,
    },
    BALANCED_MODEL_ID: {
        "unit": "vllm.service",
        "port": 8010,
        "served": "qwen3.8-27b-nvfp4",
        "hf_id": "nvidia/Qwen3.8-27B-NVFP4",
        "context": 147456,
        "max_requests": 3,
    },
    "qwen3.5-9b-nvfp4-reader": {
        "unit": "vllm-reader.service",
        # COUPLED to the reader unit's --port in esnixi/vllm.nix.
        "port": 8012,
        "served": "qwen3.5-9b-nvfp4-reader",
        "hf_id": "AxionML/Qwen3.5-9B-NVFP4",
        # COUPLED to the reader unit's served --max-model-len in esnixi/vllm.nix.
        # If these two ever disagree, select_model's readiness poll (which requires
        # max_model_len == context) never matches, burns START_SECONDS, then
        # 409s to the next tier forever. Change BOTH together. A unit test asserts
        # this equality (test_vllm_switch.py).
        "context": 65536,
        "max_requests": 8,
    },
}
PRIMARY_MODEL = "qwen3.8-27b-nvfp4"
PRIMARY_UNIT = MODELS[PRIMARY_MODEL]["unit"]
ALIASES = {}
for model_id, model in MODELS.items():
    for alias in (model_id, f"vllm/{model_id}"):
        ALIASES[alias] = model_id
ALIASES["nvidia/Qwen3.8-27B-NVFP4"] = "qwen3.8-27b-nvfp4"
ALIASES["vllm/nvidia/Qwen3.8-27B-NVFP4"] = "qwen3.8-27b-nvfp4"
BALANCED_ALIASES = {BALANCED_MODEL_ID, f"vllm/{BALANCED_MODEL_ID}"}

# All of the following are guarded by switch_condition.
switch_condition = threading.Condition()
active_model: str | None = None
active_requests = 0
switching = False
switching_to: str | None = None
last_activity: float | None = None  # monotonic; last acquire/release on active_model.
no_ready_since: float = time.monotonic()  # when active_model last became None.
# Circuit breaker per unit (both coder aliases share one engine):
# {"failures": int, "open_until": monotonic float}.
breakers: dict[str, dict] = {}


def residency_remaining(now: float) -> float:
    """Seconds the idle active model is still protected; 0 when swappable. Hold switch_condition."""
    if active_model is None or last_activity is None:
        return 0.0
    window = CODER_RESIDENCY_SECONDS if MODELS[active_model]["unit"] == PRIMARY_UNIT else RESIDENCY_SECONDS
    if window <= 0:
        return 0.0
    return max(0.0, last_activity + window - now)


def breaker_remaining(unit: str, now: float) -> float:
    """Seconds the unit's breaker stays open; 0 when closed or half-open. Hold switch_condition."""
    state = breakers.get(unit)
    if not state:
        return 0.0
    return max(0.0, state["open_until"] - now)


def record_failure(unit: str, why: str, now: float | None = None) -> float:
    """Open the unit's breaker with exponential backoff; return it. Hold switch_condition."""
    now = time.monotonic() if now is None else now
    state = breakers.setdefault(unit, {"failures": 0, "open_until": 0.0})
    state["failures"] += 1
    backoff = min(BACKOFF_SECONDS * 2 ** (state["failures"] - 1), BACKOFF_MAX_SECONDS)
    state["open_until"] = now + backoff
    LOG.warning("breaker OPEN unit=%s failures=%d backoff=%.0fs reason=%s",
                unit, state["failures"], backoff, why)
    return backoff


def reset_breaker(unit: str) -> None:
    """Close the unit's breaker after a successful start. Hold switch_condition."""
    state = breakers.pop(unit, None)
    if state and state["failures"] > 0:
        LOG.info("breaker CLOSED unit=%s after %d failure(s)", unit, state["failures"])


def _set_no_ready(now: float) -> None:
    """Clear the active model and start the watchdog clock. Hold switch_condition."""
    global active_model, last_activity, no_ready_since
    active_model = None
    last_activity = None
    no_ready_since = now


def backend_url(model_id: str) -> str:
    return f"http://127.0.0.1:{MODELS[model_id]['port']}"


def unit_port(unit: str) -> int:
    return next(m["port"] for m in MODELS.values() if m["unit"] == unit)


def model_for_unit(unit: str) -> str:
    """Canonical model id served by a unit (the primary for the coder unit)."""
    if unit == PRIMARY_UNIT:
        return PRIMARY_MODEL
    return next(mid for mid, m in MODELS.items() if m["unit"] == unit)


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


def other_units(target_unit: str) -> list[str]:
    """Every distinct vLLM unit in MODELS that is not the target unit."""
    units = {m["unit"] for m in MODELS.values()}
    return sorted(u for u in units if u != target_unit)


def unit_state(unit: str) -> tuple[str, str]:
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


def unit_running(unit: str) -> bool:
    active, _sub = unit_state(unit)
    return active == "active"


def unit_failed(unit: str) -> bool:
    try:
        return subprocess.run([SYSTEMCTL, "is-failed", "--quiet", unit], check=False,
                              timeout=5).returncode == 0
    except (subprocess.SubprocessError, OSError):
        return False


def unit_restarts(unit: str) -> int:
    """systemd NRestarts for the unit; -1 when unknown."""
    try:
        return int(subprocess.check_output(
            [SYSTEMCTL, "show", "--value", "--property=NRestarts", unit],
            text=True, timeout=5).strip())
    except (ValueError, subprocess.SubprocessError, OSError):
        return -1


def _privileged(verb: str, unit: str, timeout: float, check: bool = False) -> None:
    subprocess.run(
        [SUDO, "-n", SYSTEMCTL, verb, unit],
        check=check,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=max(1.0, timeout),
    )


def stop_and_drain(unit: str, deadline: float) -> bool:
    """Stop `unit` and wait until it is inactive/dead (VRAM returned).

    Bounded by `deadline` (monotonic). Returns True if the unit reached inactive
    within the deadline. A `systemctl stop` that outlives its timeout keeps being
    polled (systemd's SIGKILL may still land) until the deadline. nvidia-smi is NOT
    on this unit's PATH, so drain is detected via the unit's own ActiveState/SubState.
    """
    LOG.info("stopping %s", unit)
    try:
        _privileged("stop", unit, deadline - time.monotonic())
    except subprocess.TimeoutExpired:
        LOG.warning("systemctl stop %s timed out; polling until the stop deadline", unit)
    except (subprocess.SubprocessError, OSError) as error:
        LOG.warning("systemctl stop %s failed: %s", unit, error)
    while time.monotonic() < deadline:
        active, sub = unit_state(unit)
        if active in ("inactive", "failed") and sub in ("dead", "failed", ""):
            # Give the driver a moment to finish reclaiming VRAM.
            time.sleep(DRAIN_SETTLE_SECONDS)
            return True
        time.sleep(0.5)
    LOG.error("%s did not stop within its deadline", unit)
    return False


def sleep_unit(unit: str, deadline: float) -> bool:
    """Ask a running unit to sleep (weights to host RAM) and release the GPU lease.

    Retries while the unit is busy or not yet serving, within SLEEP_DRAIN_SECONDS
    (and `deadline`); every HTTP attempt is bounded by the remaining budget. Returns
    False so the caller can fall back to a full stop.
    """
    give_up = min(deadline, time.monotonic() + SLEEP_DRAIN_SECONDS)
    while True:
        remaining = give_up - time.monotonic()
        if remaining <= 0:
            break
        drain = int(max(1, min(10, remaining)))
        url = f"http://127.0.0.1:{unit_port(unit)}/arcane/sleep?timeout={drain}"
        request = urllib.request.Request(url, data=b"", method="POST")
        try:
            with urllib.request.urlopen(request, timeout=max(1.0, remaining)) as response:
                if response.status == 200:
                    return True
        except urllib.error.HTTPError as error:
            error.close()
            if error.code not in (409, 503):
                LOG.warning("sleep %s refused with HTTP %d", unit, error.code)
                return False
        except (urllib.error.URLError, OSError):
            pass
        time.sleep(0.5)
    LOG.warning("sleep %s exceeded its %.0fs budget", unit, SLEEP_DRAIN_SECONDS)
    return False


def unit_awake(unit: str) -> bool:
    """True if the running unit reports sleeping == false (GET never wakes it)."""
    request = urllib.request.Request(f"http://127.0.0.1:{unit_port(unit)}/arcane/state")
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            return json.loads(response.read()).get("sleeping") is False
    except (urllib.error.URLError, OSError, json.JSONDecodeError, ValueError, AttributeError):
        return False


def serves_model(model_id: str) -> bool:
    """One /v1/models probe: the backend serves the expected model and context."""
    selected = MODELS[model_id]
    request = urllib.request.Request(f"{backend_url(model_id)}/v1/models")
    try:
        with urllib.request.urlopen(request, timeout=3) as response:
            models = json.loads(response.read())
            return any(
                item.get("id") == selected["served"]
                and item.get("max_model_len") == selected["context"]
                for item in models.get("data", [])
            )
    except (urllib.error.URLError, OSError, json.JSONDecodeError, ValueError, AttributeError):
        return False


def wait_ready(model_id: str, deadline: float, restarts_before: int) -> tuple[bool, str]:
    """Poll the target's /v1/models until it serves the expected model/context.

    restarts_before == -1 is the warm path (no start issued): give up as soon as
    the unit is no longer running so the caller can cold-start it.
    """
    unit = MODELS[model_id]["unit"]
    while time.monotonic() < deadline:
        if restarts_before == -1 and not unit_running(unit):
            return False, "unit not running"
        if serves_model(model_id):
            return True, ""
        # An incompatible layout can fail after systemctl start returns.
        if unit_failed(unit):
            return False, "unit failed"
        if restarts_before >= 0:
            restarts_now = unit_restarts(unit)
            if restarts_now > restarts_before:
                return False, f"unit restarted (NRestarts {restarts_before}->{restarts_now})"
        time.sleep(2)
    return False, "readiness timeout"


def select_model(model_id: str, deadline: float) -> tuple[bool, str]:
    """Make `model_id` the only awake model on the GPU; (ready, failure reason)."""
    target_unit = MODELS[model_id]["unit"]
    # Single tenancy authority: every OTHER vLLM unit must give up the GPU BEFORE
    # the target runs. For a non-primary target, running units sleep (weights stay
    # in host RAM, lease released); a unit that cannot sleep is stopped and drained.
    # The coder's KV budget assumes no resident neighbour (a sleeping reader keeps
    # 1.56 GiB), so selecting the coder stops and drains every other unit. Only
    # reached with active_requests == 0 and the residency window expired.
    for other in other_units(target_unit):
        active, _sub = unit_state(other)
        if active in ("inactive", "failed", ""):
            continue
        if active == "active" and target_unit != PRIMARY_UNIT and sleep_unit(other, deadline):
            LOG.info("slept %s", other)
            continue
        if not stop_and_drain(other, time.monotonic() + STOP_SECONDS):
            return False, f"could not stop {other}"
    # Warm path: a running (possibly sleeping) target is ready as soon as it
    # answers /v1/models; its middleware takes the lease and wakes it on the
    # first engine request.
    if unit_running(target_unit):
        ok, _why = wait_ready(model_id, deadline, -1)
        if ok:
            return True, ""
    # Clear any stale `failed` state on the target so its own is-failed guard
    # (below) does not refuse to start a deliberately-stopped unit.
    try:
        _privileged("reset-failed", target_unit, SUBPROCESS_TIMEOUT_SECONDS)
    except (subprocess.SubprocessError, OSError):
        pass
    if unit_failed(target_unit):
        return False, "unit failed"
    restarts_before = unit_restarts(target_unit)
    LOG.info("starting %s", target_unit)
    try:
        _privileged("start", target_unit, min(120.0, deadline - time.monotonic()), check=True)
    except (subprocess.SubprocessError, OSError) as error:
        return False, f"systemctl start failed ({type(error).__name__})"
    return wait_ready(model_id, deadline, restarts_before)


def safe_select(model_id: str, deadline: float) -> tuple[bool, str]:
    """select_model that never raises (a raise would leave `switching` stuck)."""
    try:
        return select_model(model_id, deadline)
    except Exception as error:  # noqa: BLE001 - must always fail closed to a reject
        LOG.exception("select %s crashed", model_id)
        return False, f"error {type(error).__name__}"


_FAST_RETRY_PREFIXES = ("unit failed", "unit restarted", "systemctl start failed", "error ")


def _fast_retryable(why: str) -> bool:
    """A start/readiness failure a fresh start can fix (not a wedged neighbour or timeout)."""
    return why.startswith(_FAST_RETRY_PREFIXES)


def select_with_fast_retry(model_id: str) -> tuple[bool, str]:
    """safe_select with immediate retries for the primary coder. Lock NOT held; never raises.

    Each attempt gets its own START_SECONDS budget. Non-coder targets get one attempt.
    The caller records at most ONE breaker failure for the whole sequence.
    """
    unit = MODELS[model_id]["unit"]
    attempts = 1 + max(0, CODER_FAST_RETRIES) if unit == PRIMARY_UNIT else 1
    ok, why = False, "no attempt"
    for attempt in range(1, attempts + 1):
        ok, why = safe_select(model_id, time.monotonic() + START_SECONDS)
        if ok or unit != PRIMARY_UNIT or not _fast_retryable(why):
            return ok, why
        if attempt == attempts:
            break
        LOG.warning("coder start failed (%s); fast retry %d/%d in %.0fs",
                    why, attempt, attempts - 1, CODER_FAST_RETRY_DELAY_SECONDS)
        # Stop first so systemd's own Restart= cannot race the next start.
        try:
            if not stop_and_drain(unit, time.monotonic() + STOP_SECONDS):
                return ok, why
        except Exception:  # noqa: BLE001 - never raise into the caller
            LOG.exception("stopping %s before a fast retry crashed", unit)
            return ok, why
        time.sleep(CODER_FAST_RETRY_DELAY_SECONDS)
    LOG.error("coder start failed %d time(s) (%s); stopping crash-looping coder", attempts, why)
    try:
        stop_and_drain(unit, time.monotonic() + STOP_SECONDS)
    except Exception:  # noqa: BLE001 - never raise into the caller
        LOG.exception("stopping crash-looping %s crashed", unit)
    return ok, why


def restore_target(previous: str | None, failed_unit: str) -> str | None:
    """Model to restore after `failed_unit` failed: the previous one, else the coder."""
    candidate = previous or PRIMARY_MODEL
    if MODELS[candidate]["unit"] == failed_unit:
        candidate = PRIMARY_MODEL if PRIMARY_UNIT != failed_unit else None
    return candidate


def _busy_reject(target_unit: str) -> tuple[str, str]:
    """(code, reason) for a different-unit request while the active model is busy. Hold lock."""
    name = "coder" if MODELS[active_model]["unit"] == PRIMARY_UNIT else "reader"
    target = "coder" if target_unit == PRIMARY_UNIT else "reader"
    if active_requests > 0:
        return (f"{name}_busy",
                f"{name} busy: {active_requests} request(s) in flight; {target} not swapped in")
    hold = math.ceil(residency_remaining(time.monotonic()))
    return f"{name}_resident", f"{name} resident for {hold} s more; {target} not swapped in"


def acquire(model_id: str) -> tuple[bool, str, str, int]:
    """Admit a request for `model_id`, switching the GPU if allowed.

    Returns (ok, reject code, reject reason, Retry-After seconds or 0).
    """
    global active_model, active_requests, switching, switching_to, last_activity
    target_unit = MODELS[model_id]["unit"]
    deadline = time.monotonic() + LOCK_WAIT_SECONDS
    with switch_condition:
        while True:
            now = time.monotonic()
            hold = 0.0
            same_unit = active_model is not None and MODELS[active_model]["unit"] == target_unit
            if same_unit and not switching:
                limit = MODELS[model_id]["max_requests"]
                if active_requests < limit:
                    last_activity = now
                    active_requests += 1
                    return True, "", "", 0
                name = "coder" if target_unit == PRIMARY_UNIT else "reader"
                code, reason = f"{name}_full", f"{name} busy: {active_requests}/{limit} requests in flight"
            else:
                # Breaker first: a target in backoff never touches the active model.
                backoff = breaker_remaining(target_unit, now)
                if backoff > 0:
                    retry = math.ceil(backoff)
                    return (False, "backoff",
                            f"{model_id} in backoff for {retry} s after start failure", retry)
                if switching:
                    code, reason = "switching", f"5090 switching to {switching_to}; retry"
                elif active_model is not None and (active_requests > 0
                                                   or residency_remaining(now) > 0):
                    hold = residency_remaining(now) if active_requests == 0 else 0.0
                    code, reason = _busy_reject(target_unit)
                else:
                    previous = active_model
                    switching = True
                    switching_to = model_id
                    active_model = None
                    last_activity = None
                    break

            remaining = deadline - now
            if remaining <= 0:
                return False, code, reason, 0
            # Nothing notifies when the residency window expires, so wake at its
            # end if that comes before the lock-wait deadline.
            switch_condition.wait(min(remaining, hold) if hold > 0 else remaining)

    # Switching: the lock is NOT held from here on; others get fast 409s.
    started = time.monotonic()
    ready, why = False, "switch aborted"
    restored = None
    try:
        ready, why = select_with_fast_retry(model_id)
        if ready:
            LOG.info("switch %s -> %s ok in %.1fs", previous, model_id, time.monotonic() - started)
            return True, "", "", 0
        LOG.error("switch %s -> %s FAILED after %.1fs: %s",
                  previous, model_id, time.monotonic() - started, why)
        with switch_condition:
            backoff = record_failure(target_unit, why)
        restored = rollback(target_unit, previous)
        return (False, "start_failed",
                f"{model_id} failed to start ({why}); restored {restored or 'nothing'}; "
                f"backoff {math.ceil(backoff)} s", 0)
    finally:
        with switch_condition:
            now = time.monotonic()
            if ready:
                active_model = model_id
                last_activity = now
                active_requests += 1
                reset_breaker(target_unit)
            elif restored is not None:
                active_model = restored
                last_activity = now
            else:
                _set_no_ready(now)
            switching = False
            switching_to = None
            switch_condition.notify_all()


def rollback(failed_unit: str, previous: str | None) -> str | None:
    """Stop the failed target and restore the previous (or primary) model. Lock NOT held."""
    try:
        active, _sub = unit_state(failed_unit)
        if active not in ("inactive", "failed", ""):
            stop_and_drain(failed_unit, time.monotonic() + STOP_SECONDS)
        restore = restore_target(previous, failed_unit)
        if restore is None:
            return None
        restore_unit = MODELS[restore]["unit"]
        with switch_condition:
            if breaker_remaining(restore_unit, time.monotonic()) > 0:
                LOG.warning("not restoring %s: its breaker is open", restore)
                return None
        ok, why = select_with_fast_retry(restore)
        with switch_condition:
            if ok:
                reset_breaker(restore_unit)
            else:
                record_failure(restore_unit, f"restore failed: {why}")
        if ok:
            LOG.info("rollback restored %s", restore)
            return restore
        LOG.error("rollback could not restore %s: %s", restore, why)
    except Exception:  # noqa: BLE001 - rollback must never raise into the request
        LOG.exception("rollback after %s failure crashed", failed_unit)
    return None


def release() -> None:
    global active_requests, last_activity
    with switch_condition:
        if active_requests > 0:
            active_requests -= 1
        if active_model is not None:
            last_activity = time.monotonic()
        # Idle readers put themselves to sleep (vllm_idle.py VLLM_IDLE_SECONDS); the
        # switcher stops the reader only when it next selects the coder.
        switch_condition.notify_all()


def adopt_awake_unit() -> str | None:
    """Model of a running unit that is already awake and serving (never wakes anything)."""
    for unit in [PRIMARY_UNIT] + other_units(PRIMARY_UNIT):
        if unit_running(unit) and unit_awake(unit):
            model_id = model_for_unit(unit)
            if serves_model(model_id):
                return model_id
    return None


def watchdog_tick(now: float | None = None) -> str | None:
    """One liveness check; returns the action taken (for logs/tests) or None."""
    global switching, switching_to, active_model, last_activity
    now = time.monotonic() if now is None else now
    with switch_condition:
        if switching or active_requests > 0:
            return None
        current = active_model
        if current is None:
            if now - no_ready_since < WATCHDOG_SECONDS:
                return None
            if breaker_remaining(PRIMARY_UNIT, now) > 0:
                return None
            switching = True
            switching_to = PRIMARY_MODEL

    if current is not None:
        # (a) the active model's unit died underneath us: start the no-ready clock.
        if unit_running(MODELS[current]["unit"]):
            return None
        with switch_condition:
            if active_model == current and not switching and active_requests == 0:
                LOG.warning("watchdog: %s unit is not running; clearing active model", current)
                _set_no_ready(now)
                return "cleared"
        return None

    # (b) nothing ready for WATCHDOG_SECONDS: adopt an awake unit or ready the coder.
    adopted = None
    why = ""
    try:
        adopted = adopt_awake_unit()
        if adopted is not None:
            LOG.info("watchdog: adopted awake %s", adopted)
        else:
            LOG.warning("watchdog: no model ready for %.0fs; readying %s",
                        now - no_ready_since, PRIMARY_MODEL)
            ok, why = select_with_fast_retry(PRIMARY_MODEL)
            adopted = PRIMARY_MODEL if ok else None
    except Exception as error:  # noqa: BLE001 - watchdog must not leave `switching` stuck
        LOG.exception("watchdog recovery crashed")
        why = f"error {type(error).__name__}"
    finally:
        with switch_condition:
            done = time.monotonic()
            if adopted is not None:
                active_model = adopted
                last_activity = done
                reset_breaker(MODELS[adopted]["unit"])
            else:
                record_failure(PRIMARY_UNIT, f"watchdog: {why}")
                _set_no_ready(done)
            switching = False
            switching_to = None
            switch_condition.notify_all()
    return f"ready {adopted}" if adopted else "failed"


def watchdog_loop(stop: threading.Event | None = None) -> None:
    """Run watchdog_tick forever; an exception is logged and never kills the loop."""
    while stop is None or not stop.is_set():
        try:
            watchdog_tick()
        except Exception:  # noqa: BLE001 - the watchdog must never die silently
            LOG.exception("watchdog tick failed")
        time.sleep(WATCHDOG_INTERVAL_SECONDS)


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

    def json_response(self, status: int, payload: dict, headers: dict | None = None) -> None:
        body = json.dumps(payload, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for name, value in (headers or {}).items():
            self.send_header(name, value)
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
            # Always 409: OmniRoute falls back to the next tier on it. The reason
            # (and code) say why, so OmniRoute logs show it.
            reason = self.reject_reason or "busy"
            LOG.info("409 model=%s code=%s reason=%s", model_id, self.reject_code, reason)
            self.json_response(
                409,
                {"error": {
                    "message": f"RTX 5090 is busy; use the next OmniRoute fallback ({reason})",
                    "type": "vllm_switch_unavailable",
                    "code": self.reject_code or "busy",
                }},
                {"Retry-After": str(self.retry_after)} if self.retry_after > 0 else None,
            )
            return
        try:
            self.proxy(path, body, model_id)
        finally:
            self.release_model()

    reject_code = ""
    reject_reason = ""
    retry_after = 0

    def acquire_model(self, model_id: str) -> bool:
        """Serialize both logical aliases against the one loaded model."""
        ok, self.reject_code, self.reject_reason, self.retry_after = acquire(model_id)
        return ok

    def release_model(self) -> None:
        release()

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
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    threading.Thread(target=watchdog_loop, name="vllm-switch-watchdog", daemon=True).start()
    Server(("127.0.0.1", 8011), Handler).serve_forever()
