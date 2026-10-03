#!/usr/bin/env python3
"""Bounded concurrent inference workers for Zoo's serial MCP tool loop.

Workers receive explicit context, return proposals, and never execute tools or
edit files. The parent agent owns repository access, validation, and integration.
"""
import concurrent.futures as futures
import contextlib
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
import importlib.util

def list_zoo_chats():
    spec = importlib.util.spec_from_file_location("zoo_chats", Path(__file__).with_name("zoo_chats.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.list_chats()

LANES = {
    "code": ("local/5090", "esnixi", 2),
    "fast": ("local/4070ti", "gremlin-1", 1),
    "long": ("local/m5max", "stabulous", 1),
}
BASE = os.environ.get("OMNIROUTE_BASE_URL", "https://omniroute.celestium.life/v1").rstrip("/")
STATE = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "omniroute-workers"
MAX_ACTIVE = 12
MAX_BATCH = 6
TIMEOUT = 600
LOCK = threading.RLock()
BATCHES = {}
POOLS = {lane: futures.ThreadPoolExecutor(max_workers=cap) for lane, (_, _, cap) in LANES.items()}


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


@contextlib.contextmanager
def host_slot(lane, cancel):
    # Shared across all Zoo/other MCP client processes on this host. Gateway
    # connection caps remain the final guard for clients on other machines.
    _, host, cap = LANES[lane]
    directory = STATE / "leases"
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    handles = [open(directory / f"{host}-{i}.lock", "a") for i in range(cap)]
    acquired = None
    deadline = time.monotonic() + TIMEOUT
    try:
        while acquired is None:
            if cancel.is_set():
                raise RuntimeError("Cancelled before dispatch")
            if time.monotonic() >= deadline:
                raise TimeoutError("Host capacity wait exceeded 600 seconds")
            for handle in handles:
                try:
                    fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    acquired = handle
                    break
                except BlockingIOError:
                    pass
            if acquired is None:
                cancel.wait(0.1)
        yield
    finally:
        for handle in handles:
            handle.close()


def audit(result):
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    fields = {k: v for k, v in result.items() if k not in {"text", "error"}}
    with open(STATE / "timings.jsonl", "a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.write(json.dumps(fields) + "\n")


def run_task(task, submitted, cancel, batch_id):
    route, host, _ = LANES[task["lane"]]
    result = {"id": task["id"], "batch_id": batch_id, "lane": task["lane"], "route": route, "host": host}
    started = None
    try:
        with host_slot(task["lane"], cancel):
            started = time.monotonic()
            result.update(started_at=now(), queue_ms=round((started - submitted) * 1000))
            prompt = task["prompt"]
            if task.get("context"):
                prompt += "\n\nContext supplied by the parent agent:\n" + task["context"]
            payload = {
                "model": route, "stream": True,
                "messages": [
                    {"role": "system", "content": "Work only on the supplied independent task and context. Return a concise, evidence-based answer or proposed patch. You cannot read files, execute tools, or apply changes. State missing evidence; do not claim to have run tests or changed files."},
                    {"role": "user", "content": prompt},
                ],
                "max_tokens": task.get("max_tokens", 4096),
                "reasoning_effort": task.get("reasoning_effort", "low"),
                "stream_options": {"include_usage": True},
            }
            headers = {"Content-Type": "application/json", "User-Agent": "OmniRoute-Workers/1.0", "X-Omniroute-Session-Id": f"worker-{batch_id}-{task['id']}"}
            key = os.environ.get("OMNIROUTE_API_KEY")
            if key:
                headers["Authorization"] = "Bearer " + key
            content = []
            complete = False
            command = ["curl", "--fail-with-body", "--silent", "--show-error", "--no-buffer",
                "--max-time", str(TIMEOUT), "-X", "POST"]
            for name, value in headers.items():
                command.extend(["-H", f"{name}: {value}"])
            command.extend(["--data-binary", "@-", BASE + "/chat/completions"])
            with subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE) as process:
                process.stdin.write(json.dumps(payload).encode())
                process.stdin.close()
                result["status"] = 200
                for raw in process.stdout:
                    if cancel.is_set():
                        process.terminate()
                        raise RuntimeError("Cancelled during generation")
                    if time.monotonic() - started > TIMEOUT:
                        raise TimeoutError("Generation exceeded 600 seconds")
                    if not raw.startswith(b"data:"):
                        continue
                    data = raw[5:].strip()
                    if data == b"[DONE]":
                        complete = True
                        break
                    if not data:
                        continue
                    event = json.loads(data)
                    if event.get("error"):
                        raise RuntimeError(str(event["error"])[:500])
                    if event.get("model"):
                        result["model"] = event["model"]
                    if event.get("usage"):
                        result["usage"] = event["usage"]
                    for choice in event.get("choices", []):
                        delta = choice.get("delta", {})
                        if delta.get("content") or delta.get("reasoning_content"):
                            result.setdefault("ttft_ms", round((time.monotonic() - started) * 1000))
                        if isinstance(delta.get("content"), str):
                            content.append(delta["content"])
                        if choice.get("finish_reason"):
                            complete = True
                            result["finish_reason"] = choice["finish_reason"]
                stderr = process.stderr.read().decode(errors="replace")
                returncode = process.wait()
                if returncode:
                    raise RuntimeError(f"curl {returncode}: {stderr[:500]}")
            if not complete:
                raise RuntimeError("Upstream stream ended without completion")
            result.update(state="completed", text="".join(content))
    except (urllib.error.URLError, OSError, ValueError, RuntimeError) as error:
        result.update(state="cancelled" if cancel.is_set() else "failed", error=str(error)[:500])
        if isinstance(error, urllib.error.HTTPError):
            result["status"] = error.code
    finally:
        result.update(finished_at=now(), elapsed_ms=round((time.monotonic() - submitted) * 1000))
        if started is not None:
            result["service_ms"] = round((time.monotonic() - started) * 1000)
        audit(result)
    return result


def validate_tasks(tasks):
    if not isinstance(tasks, list) or not 1 <= len(tasks) <= MAX_BATCH:
        raise ValueError("Supply 1–6 independent tasks")
    ids = set()
    for task in tasks:
        if not isinstance(task, dict) or task.get("lane") not in LANES:
            raise ValueError("Each task requires lane code, fast, or long")
        task_id = task.get("id")
        if not isinstance(task_id, str) or not task_id or len(task_id) > 80 or task_id in ids:
            raise ValueError("Task ids must be unique nonempty strings of at most 80 characters")
        ids.add(task_id)
        if not isinstance(task.get("prompt"), str) or not task["prompt"].strip():
            raise ValueError("Each task requires a prompt")
        if not isinstance(task.get("context", ""), str) or len(task["prompt"]) + len(task.get("context", "")) > 240000:
            raise ValueError("Prompt and context must total at most 240000 characters")
        if type(task.get("max_tokens", 4096)) is not int or not 64 <= task.get("max_tokens", 4096) <= 8192:
            raise ValueError("max_tokens must be between 64 and 8192")
        if task.get("reasoning_effort", "low") not in ("none", "low", "medium"):
            raise ValueError("reasoning_effort must be none, low, or medium")
    if sum(len(t["prompt"]) + len(t.get("context", "")) for t in tasks) > 480000:
        raise ValueError("Batch context exceeds 480000 characters")


def start_batch(tasks):
    validate_tasks(tasks)
    with LOCK:
        # Bound retained responses, and never discard an active batch.
        for key, batch in list(BATCHES.items()):
            if all(f.done() for f in batch["futures"]) and time.monotonic() - batch["created"] > 3600:
                del BATCHES[key]
        if len(BATCHES) >= 32:
            raise ValueError("32 retained batches; restart the MCP server after collecting results")
        active = sum(not f.done() for b in BATCHES.values() for f in b["futures"])
        if active + len(tasks) > MAX_ACTIVE:
            raise ValueError("At most 12 queued/running tasks; collect existing batches first")
        batch_id = uuid.uuid4().hex
        submitted = time.monotonic()
        cancel = threading.Event()
        batch = {"created": submitted, "cancel": cancel, "ids": [t["id"] for t in tasks], "futures": []}
        BATCHES[batch_id] = batch
        batch["futures"] = [POOLS[t["lane"]].submit(run_task, t, submitted, cancel, batch_id) for t in tasks]
        return get_batch(batch_id)


def get_batch(batch_id):
    with LOCK:
        batch = BATCHES.get(batch_id)
        if batch is None:
            raise ValueError("Unknown batch id in this MCP server session")
        results = []
        for task_id, future in zip(batch["ids"], batch["futures"]):
            if future.cancelled():
                results.append({"id": task_id, "state": "cancelled"})
            elif future.done():
                try:
                    results.append(future.result())
                except Exception as error:
                    results.append({"id": task_id, "state": "failed", "error": str(error)[:500]})
            else:
                results.append({"id": task_id, "state": "running_or_queued"})
        return {"batch_id": batch_id, "done": all(f.done() for f in batch["futures"]), "tasks": results}


TASK_SCHEMA = {"type": "object", "properties": {
    "id": {"type": "string"}, "lane": {"type": "string", "enum": list(LANES)},
    "prompt": {"type": "string"}, "context": {"type": "string"},
    "max_tokens": {"type": "integer", "minimum": 64, "maximum": 8192},
    "reasoning_effort": {"type": "string", "enum": ["none", "low", "medium"]},
}, "required": ["id", "lane", "prompt"], "additionalProperties": False}
TOOLS = [
    {"name": "list_zoo_chats", "description": "Read current Zoo chats, task IDs, mode/model, checklist progress and parent links from native Task Board snapshots. Includes freshness; stale boards are not live execution evidence. Open Zoo: Show Task Board to publish snapshots.", "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "start_parallel_tasks", "description": "Start 1–6 independent inference tasks concurrently. Supply context explicitly. code uses esnixi RTX 5090 (2 slots); fast uses gremlin-1 Ornith (1 slot); long uses stabulous GLM 160K (1 slot). Workers return analysis or proposed code; they cannot read files, run tools, or edit. Returns immediately. Use different lanes to engage multiple GPUs, then collect every result with get_parallel_tasks. No automatic cloud fallback.", "inputSchema": {"type": "object", "properties": {"tasks": {"type": "array", "minItems": 1, "maxItems": 6, "items": TASK_SCHEMA}}, "required": ["tasks"], "additionalProperties": False}},
    {"name": "get_parallel_tasks", "description": "Read a batch's results and timing. Poll while doing useful parent work; unfinished jobs continue in the background. Results remain for one hour in this server session.", "inputSchema": {"type": "object", "properties": {"batch_id": {"type": "string"}}, "required": ["batch_id"], "additionalProperties": False}},
    {"name": "cancel_parallel_tasks", "description": "Cancel queued tasks and signal running streams to close on their next event (bounded by the HTTP timeout).", "inputSchema": {"type": "object", "properties": {"batch_id": {"type": "string"}}, "required": ["batch_id"], "additionalProperties": False}},
]


def rpc(message):
    method, params = message.get("method"), message.get("params", {})
    if method == "initialize":
        return {"protocolVersion": params.get("protocolVersion", "2025-03-26"), "capabilities": {"tools": {}}, "serverInfo": {"name": "omniroute-workers", "version": "1.0.0"}}
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        try:
            name, args = params["name"], params.get("arguments", {})
            if name == "list_zoo_chats":
                result = list_zoo_chats()
            elif name == "start_parallel_tasks":
                result = start_batch(args["tasks"])
            elif name == "get_parallel_tasks":
                result = get_batch(args["batch_id"])
            elif name == "cancel_parallel_tasks":
                with LOCK:
                    batch = BATCHES[args["batch_id"]]
                    batch["cancel"].set()
                    for future in batch["futures"]:
                        future.cancel()
                result = get_batch(args["batch_id"])
            else:
                raise ValueError("Unknown tool")
            return {"content": [{"type": "text", "text": json.dumps(result)}]}
        except (KeyError, TypeError, ValueError) as error:
            return {"isError": True, "content": [{"type": "text", "text": str(error)}]}
    raise ValueError("Unknown method")


def main():
    try:
        for line in sys.stdin:
            message = None
            try:
                if len(line) > 3000000:
                    raise ValueError("MCP message too large")
                message = json.loads(line)
                if not isinstance(message, dict):
                    raise ValueError("JSON-RPC object required")
                if "id" not in message:
                    continue
                output = {"jsonrpc": "2.0", "id": message["id"], "result": rpc(message)}
            except (ValueError, TypeError) as error:
                output = {"jsonrpc": "2.0", "id": message.get("id") if isinstance(message, dict) else None, "error": {"code": -32600, "message": str(error)}}
            print(json.dumps(output), flush=True)
    finally:
        for batch in BATCHES.values():
            batch["cancel"].set()
        for pool in POOLS.values():
            pool.shutdown(wait=False, cancel_futures=True)


if __name__ == "__main__":
    main()
