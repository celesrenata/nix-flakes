#!/usr/bin/env python3
"""Review/apply only the local GPU routing policy through OmniRoute's API."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import urllib.request

CONNECTIONS = {
    "vllm": "e9bd13fb-c6b6-4c18-b42f-3395266348ce",  # esnixi native vLLM
    "ollama-local": "b20e0770-3e14-40c1-87cd-85c34b34381a",  # gremlin Ollama
    "llama-cpp": "70b82fc9-6f96-41ac-aa16-8da6099dd7ac",  # stabulous proxy
    "ollama-m5-reader": "598cf9d0-c780-4534-ae12-db324c99b588",  # stabulous Ollama
}
NAMES = ["local/code", "hybrid/code", "local/long", "hybrid/long", "hybrid/tiny", "local/5090", "local/4070ti", "local/m5max", "local/fast", "local/m5-reader", "hybrid/reader", "hybrid/fast", "hybrid/planner", "hybrid/reviewer", "hybrid/tester"]


def pin(step):
    step = dict(step)
    provider = step.get("providerId") or step.get("model", "").split("/")[0]
    if provider in CONNECTIONS and not step.get("connectionId"):
        step["connectionId"] = CONNECTIONS[provider]
    return step


def target(step_id, model, connection=None):
    step = {"id": step_id, "kind": "model", "model": model, "providerId": model.split("/")[0], "weight": 0}
    if connection:
        step["connectionId"] = CONNECTIONS[connection]
    return pin(step)


def desired(combo):
    name = combo["name"]
    models = [pin(m) for m in combo["models"]]
    # Runtime config's API schema rejects these obsolete stored UI fields.
    config = {k: v for k, v in combo.get("config", {}).items() if k not in {"healthCheckEnabled", "healthCheckTimeoutMs", "timeoutMs"}}
    out = {"models": models, "config": config}
    if name == "local/code":
        # Keep this selection limited to the two Qwen GPUs. A zero-weight GLM
        # step still becomes primary after a session pin or other reordering;
        # hybrid/code provides GLM as a separate fallback tier instead.
        out["strategy"] = "weighted"
        out["models"] = [
            {**m, "weight": 65} for m in models
            if m.get("connectionId") not in {CONNECTIONS["ollama-local"], CONNECTIONS["llama-cpp"]}
            and m.get("id") != "local-code-glm53-overflow"
        ] + [
            {**target("local-code-qwen38-4070", "ollama-local/qwen3.8:27b-iq3-code144k"), "weight": 35},
        ]
        config.update(concurrencyPerModel=1, queueTimeoutMs=1000, disableSessionStickiness=False, stickyRoundRobinLimit=1, stickyWeightedLimit=1)
    elif name == "hybrid/code":
        models = [m for m in models if m.get("providerId") not in {"vllm", "ollama-local", "llama-cpp"} and m.get("comboName") != "local/code"]
        out["models"] = [
            {"id": "hybrid-code-local-gpus", "kind": "combo-ref", "comboName": "local/code", "weight": 0},
            target("hybrid-code-glm53-overflow", "llama-cpp/ds4-glm53"),
        ] + models
        config.update(nestedComboMode="execute", disableSessionStickiness=True, targetTimeoutMs=240000)
    elif name == "local/long":
        # Keep long work on Stabulous by default. If it is at capacity, spill to
        # the 4070, then use the 5090's canonical Qwen target as the last local fallback.
        out["strategy"] = "priority"
        out["models"] = [
            target("local-long-glm53", "llama-cpp/ds4-glm53"),
            target("local-long-ornith4070-fallback", "ollama-local/ornith-1.5:9b-262k"),
            target("local-long-qwen5090-fallback", "vllm/qwen3.8-27b-nvfp4"),
        ]
        out["context_length"] = 163840
    elif name == "hybrid/planner":
        # The single canonical 5090 model handles ordinary planner contexts; the
        # long-context local combo remains next for requests beyond its window
        # or while the 5090 is occupied. Preserve cloud fallbacks after that.
        out["strategy"] = "priority"
        out["models"] = [target("hybrid-planner-qwen5090", "vllm/qwen3.8-27b-nvfp4")] + [
            m for m in models if m.get("id") != "hybrid-planner-qwen5090"
        ]
        config.update(queueTimeoutMs=1000, disableSessionStickiness=True)
    elif name == "hybrid/long":
        out["models"] = [target("hybrid-long-glm53", "llama-cpp/ds4-glm53")] + [m for m in models if m.get("model") != "llama-cpp/ds4-glm53"]
        # Keep the original large-context cloud route ceiling and fallback order.
    elif name == "local/m5-reader":
        out["strategy"] = "priority"
        out["models"] = [target("local-m5-reader-qwen35", "ollama-local/qwen3.5-reader:9b", "ollama-m5-reader")]
        out["context_length"] = 32768
        config.update(concurrencyPerModel=1, queueTimeoutMs=1000, targetTimeoutMs=120000, disableSessionStickiness=True, trackMetrics=True)
    elif name == "hybrid/reader":
        # Tiered reader fabric (priority = strict step order, overflow is
        # ERROR-DRIVEN): tier 1 esnixi 5090 NVFP4 reader (PRIMARY; reachable only
        # when the switcher is NOT serving the coder -- enforced by the switcher's
        # 409, which drives overflow to the next tier), tier 2 gremlin 4070 Ti Super
        # fallback reader, tier 3 M5 Max. Per the authoritative task (user msg 12:
        # "5090, fallback to 4070 ti super") the 5090 is primary and the 4070 Ti
        # Super is the fallback. Tiers 2 and 3 share the model string but are pinned
        # to DIFFERENT connections (the connectionId is the dispatch pin).
        # context_length is the most-constrained tier (M5, 32768).
        out["strategy"] = "priority"
        out["models"] = [
            target("reader-t1-esnixi-5090", "vllm/qwen3.5-9b-nvfp4-reader", "vllm"),
            target("reader-t2-gremlin-4070ti", "ollama/qwen3.5-reader:9b", "ollama-local"),
            target("reader-t3-m5max", "ollama/qwen3.5-reader:9b", "ollama-m5-reader"),
        ]
        out["context_length"] = 32768
        config.update(queueTimeoutMs=1000, targetTimeoutMs=120000, disableSessionStickiness=True, trackMetrics=True)
    elif name == "hybrid/tiny":
        # Keep the generic route on models that answer correctly without a
        # client-side reasoning-effort override. The M5 reader has its own lane.
        out["strategy"] = "priority"
        out["models"] = [target("hybrid-tiny-ornith", "ollama-local/ornith-1.5:9b-262k"), target("hybrid-tiny-qwen5090", "vllm/qwen3.8-27b-nvfp4")] + [m for m in models if m.get("providerId") not in CONNECTIONS]
        config.update(queueTimeoutMs=1000, disableSessionStickiness=True)
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default=os.environ.get("OMNIROUTE_MANAGEMENT_URL", "https://omniroute.celestium.life"))
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--code-only", action="store_true", help="Update only the local and hybrid Code combos")
    parser.add_argument("--full-context-only", action="store_true", help="Update only the 5090 full-context catalog limits")
    parser.add_argument("--backup-dir", type=Path, default=Path.home()/".local/state/omniroute-routing")
    args = parser.parse_args()
    # The v2 policy owns category routes; avoid re-applying the retired flat policy.
    tier_state = Path.home()/".local/state/omniroute-routing/tier-switch-state.json"
    if tier_state.exists() and not args.full_context_only:
        import sys
        tier_script = Path.home()/".local/share/omniroute-editor/omniroute-mode.py"
        mode = json.loads(tier_state.read_text()).get("active_mode", "tiered")
        command = [sys.executable, str(tier_script), mode, "--base-url", args.base_url]
        if args.apply: command.append("--apply")
        raise SystemExit(subprocess.call(command))

    if args.code_only and args.full_context_only:
        parser.error("Choose one scoped update")
    def request(path, data=None, method=None):
        verb = method or ("PUT" if data is not None else "GET")
        command = ["curl", "--fail-with-body", "--silent", "--show-error", "--max-time", "30",
            "-X", verb, "-H", "Content-Type: application/json", args.base_url.rstrip("/")+path]
        api_key = os.environ.get("OMNIROUTE_API_KEY")
        if api_key:
            command.extend(["-H", "Authorization: Bearer " + api_key])
        payload = None
        if data is not None:
            command.extend(["--data-binary", "@-"])
            payload = json.dumps(data).encode()
        result = subprocess.run(command, input=payload, capture_output=True)
        if result.returncode:
            detail = (result.stdout + result.stderr).decode(errors="replace")[:1500]
            raise RuntimeError(f"{verb} {path}: curl {result.returncode}: {detail}")
        return json.loads(result.stdout)
    listing = request("/api/combos")
    combos = listing.get("combos", listing) if isinstance(listing, dict) else listing
    names = [] if args.full_context_only else (["local/code", "hybrid/code"] if args.code_only else NAMES)
    selected = {c["name"]: c for c in combos if c["name"] in names}
    if set(selected) != set(names):
        raise RuntimeError("Missing expected combos; refusing partial configuration")
    plan = []
    for name in names:
        combo = request("/api/combos/"+selected[name]["id"])
        patch = desired(combo)
        if any(combo.get(k) != v for k, v in patch.items()):
            plan.append((combo, patch))
    provider_policy = {
        "d1e3ee59-0182-4cda-932b-c1950f1d5f75": {"isActive": False},
        # Matches the 5090 coder's 3 vLLM sequences / switcher max_requests 3.
        CONNECTIONS["vllm"]: {"maxConcurrent": 3},
        CONNECTIONS["ollama-local"]: {"maxConcurrent": 1},
        CONNECTIONS["llama-cpp"]: {"maxConcurrent": 1, "defaultModel": "ds4-glm53"},
        CONNECTIONS["ollama-m5-reader"]: {"maxConcurrent": 1, "defaultModel": "qwen3.5-reader:9b"},
    }
    if args.code_only or args.full_context_only:
        provider_policy = {}
    provider_plan = []
    for ident, patch in provider_policy.items():
        connection = request("/api/providers/"+ident)["connection"]
        before = {key: connection.get(key) for key in patch}
        if before != patch:
            provider_plan.append({"id": ident, "name": connection["name"], "before": before, "patch": patch})
    if args.apply and any(any(m.get("model") == "ollama-local/ornith-1.5:9b-code32k" for m in patch["models"]) for _, patch in plan):
        # Refuse to route live Code traffic to an alias that the backend or
        # OmniRoute has not yet discovered. Provision it before applying.
        alias = "ornith-1.5:9b-code32k"
        catalog = request("/api/provider-models?provider=ollama-local")
        synced = request("/api/providers/" + CONNECTIONS["ollama-local"] + "/models")
        overrides = request("/api/model-capability-overrides")
        if not any(model.get("id") == alias for model in catalog.get("models", [])):
            raise RuntimeError("Register the bounded Ornith alias in OmniRoute's model catalog first")
        if alias not in json.dumps(synced.get("models", [])):
            raise RuntimeError("Sync the gremlin Ollama connection's models before routing Code to the alias")
        if not any(o.get("target") == "ollama-local/" + alias and o.get("key") == "context_length" and o.get("value") == 32768 for o in overrides.get("overrides", [])):
            raise RuntimeError("Set the bounded Ornith alias context override to 32768 first")
    if args.apply and any(any(m.get("model") == "ollama-local/qwen3.8:27b-iq3-code144k" for m in patch["models"]) for _, patch in plan):
        alias = "qwen3.8:27b-iq3-code144k"
        catalog = request("/api/provider-models?provider=ollama-local")
        synced = request("/api/providers/" + CONNECTIONS["ollama-local"] + "/models")
        overrides = request("/api/model-capability-overrides")
        if not any(model.get("id") == alias for model in catalog.get("models", [])):
            raise RuntimeError("Register the Qwen3.8 4070 alias in OmniRoute's model catalog first")
        if alias not in json.dumps(synced.get("models", [])):
            raise RuntimeError("Sync the gremlin Ollama connection's models before routing Code to Qwen3.8")
        for key, value in (("context_length", 147456), ("max_input_tokens", 114688), ("max_output_tokens", 16384)):
            if not any(o.get("target") == "ollama-local/" + alias and o.get("key") == key and o.get("value") == value for o in overrides.get("overrides", [])):
                raise RuntimeError(f"Set the Qwen3.8 4070 alias {key} override to {value} first")
    override_plan = []
    if not args.code_only:
        current_overrides = request("/api/model-capability-overrides").get("overrides", [])
        layouts = {
            "vllm/qwen3.8-27b-nvfp4": (131072, 98304),
            "vllm/qwen3.8-27b-nvfp4-balanced": (131072, 65536),
                    }
        for target, (context, max_input) in layouts.items():
            for key, value in (("context_length", context), ("max_input_tokens", max_input)):
                current = next((o.get("value") for o in current_overrides if o.get("target") == target and o.get("key") == key), None)
                if current != value:
                    override_plan.append({"target": target, "key": key, "value": value, "before": current})
    print(json.dumps({"changes":[{"id":c["id"],"name":c["name"],"patch":p} for c,p in plan], "providerChanges": provider_plan, "modelOverrides": override_plan},indent=2))
    if args.apply and plan:
        args.backup_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        backup = args.backup_dir/(stamp+"-combos-before.json")
        backup.write_text(json.dumps([c for c,_ in plan],indent=2)+"\n")
        for combo, patch in plan:
            # Avoid overwriting a concurrent editor's changes between plan/apply.
            if request("/api/combos/"+combo["id"]) != combo:
                raise RuntimeError("Combo changed concurrently: "+combo["name"])
            request("/api/combos/"+combo["id"], patch)
            actual = request("/api/combos/"+combo["id"])
            for key, value in patch.items():
                if key == "models":
                    if len(actual[key]) != len(value) or any(any(a.get(k) != v for k, v in b.items()) for a, b in zip(actual[key], value)):
                        raise RuntimeError("Model readback mismatch: "+combo["name"])
                elif actual.get(key) != value:
                    raise RuntimeError("Readback mismatch: "+combo["name"]+" "+key)
            print("Applied "+combo["name"])
        print("Backup: "+str(backup))
    if args.apply and override_plan:
        args.backup_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        backup = args.backup_dir/(stamp+"-model-overrides-before.json")
        backup.write_text(json.dumps(override_plan, indent=2)+"\n")
        for override in override_plan:
            current = request("/api/model-capability-overrides").get("overrides", [])
            before = next((o.get("value") for o in current if o.get("target") == override["target"] and o.get("key") == override["key"]), None)
            if before != override["before"]:
                raise RuntimeError("Model override changed concurrently: "+override["key"])
            request("/api/model-capability-overrides", {k: override[k] for k in ("target", "key", "value")}, method="PATCH")
            actual = request("/api/model-capability-overrides").get("overrides", [])
            if not any(o.get("target") == override["target"] and o.get("key") == override["key"] and o.get("value") == override["value"] for o in actual):
                raise RuntimeError("Model override readback mismatch: "+override["key"])
            print("Applied 5090 layout override "+override["key"])
        print("Backup: "+str(backup))
    if args.apply and provider_plan:
        args.backup_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        backup = args.backup_dir/(stamp+"-providers-before.json")
        # Only public routing fields are saved; never provider credentials.
        backup.write_text(json.dumps(provider_plan,indent=2)+"\n")
        for change in provider_plan:
            path = "/api/providers/"+change["id"]
            current = request(path)["connection"]
            if any(current.get(k) != v for k, v in change["before"].items()):
                raise RuntimeError("Provider changed concurrently: "+change["name"])
            request(path, change["patch"])
            current = request(path)["connection"]
            if any(current.get(k) != v for k, v in change["patch"].items()):
                raise RuntimeError("Provider readback mismatch: "+change["name"])
            print("Applied provider "+change["name"])
        print("Backup: "+str(backup))


if __name__ == "__main__":
    main()
