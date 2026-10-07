#!/usr/bin/env python3
"""Merge the owned Zoo mode/flags into the existing import file, retaining profiles."""
import json, os, shutil, sys
from pathlib import Path

def configure(profile_path, *mode_paths):
    path = Path(profile_path)
    modes_to_merge = [json.loads(Path(mode_path).read_text()) for mode_path in mode_paths]
    if not path.is_file():
        return False
    data = json.loads(path.read_text())
    profiles = data["providerProfiles"]
    available = {value.get("id") for value in profiles["apiConfigs"].values()}
    required = {"omni-hybrid-planner", "omni-local-gremlin", "omni-local-long"}
    missing = required - available
    if missing:
        raise ValueError(f"Required existing OmniRoute profiles are missing: {sorted(missing)}")
    backup = path.with_name(path.name + ".before-native-parallel")
    if not backup.exists():
        shutil.copyfile(path, backup)
        backup.chmod(0o600)
    # A separate small reader on stabulous can run while its large GLM model
    # remains resident. Preserve Code and long-task profile definitions.
    reader = dict(profiles["apiConfigs"]["OmniRoute-Local-Gremlin"])
    reader.update(id="omni-local-m5-reader", openAiModelId="local/m5-reader", enableReasoningEffort=True)
    reader["openAiCustomModelInfo"] = {
        **reader["openAiCustomModelInfo"],
        "maxTokens": 4096,
        "contextWindow": 32768,
        "supportsImages": False,
        "supportsReasoningEffort": True,
        "reasoningEffort": "none",
    }
    profiles["apiConfigs"]["OmniRoute-Local-M5-Reader"] = reader
    # Task-level tiers retain the category profile and its reasoning effort.
    # Explicit local profiles remain available; custom reasoning modes use hybrid roots.
    hybrid_reader = dict(reader)
    hybrid_reader.update(id="omni-hybrid-reader", openAiModelId="hybrid/reader")
    profiles["apiConfigs"]["OmniRoute-Hybrid-Reader"] = hybrid_reader
    research = dict(profiles["apiConfigs"]["OmniRoute-Local-Long"])
    research.update(id="omni-hybrid-research", openAiModelId="hybrid/research")
    research["openAiCustomModelInfo"] = {**research["openAiCustomModelInfo"], "contextWindow": 262144}
    profiles["apiConfigs"]["OmniRoute-Hybrid-Research"] = research
    for profile in profiles["apiConfigs"].values():
        model = profile.get("openAiModelId", "")
        if model.startswith("hybrid/") and model not in {"hybrid/reader", "hybrid/tiny"}:
            profile["openAiCustomModelInfo"] = {**profile.get("openAiCustomModelInfo", {}), "contextWindow": 262144}
        elif model == "local/5090":
            profile["openAiCustomModelInfo"] = {**profile.get("openAiCustomModelInfo", {}), "contextWindow": 163840}
        elif model in {"local/code", "local/long"}:
            profile["openAiCustomModelInfo"] = {**profile.get("openAiCustomModelInfo", {}), "contextWindow": 163840}
    settings = data.setdefault("globalSettings", {})
    settings.setdefault("experiments", {}).update(parallelTasks=True, parallelToolExecution=True, runSlashCommand=True)
    # Checklists are a provider-profile setting, not a global setting.
    settings.pop("todoListEnabled", None)
    for profile in profiles["apiConfigs"].values():
        profile["todoListEnabled"] = True
    modes = settings.setdefault("customModes", [])
    mode_profiles = {"spec-orchestrator": "omni-hybrid-planner", "project-reader": "omni-hybrid-reader", "project-research": "omni-hybrid-research"}
    mode_api_configs = profiles.setdefault("modeApiConfigs", {})
    for mode in modes_to_merge:
        modes[:] = [item for item in modes if item.get("slug") != mode["slug"]] + [mode]
        if mode["slug"] not in mode_profiles:
            raise ValueError(f"No OmniRoute profile mapping is defined for {mode['slug']}")
        mode_api_configs[mode["slug"]] = mode_profiles[mode["slug"]]
    # Independent repository research uses the warm M5 long-context model.
    # Keep Code, planning and explicit long-task profiles unchanged.
    profiles["modeApiConfigs"]["project-research"] = "omni-hybrid-research"
    # The orchestrator/spec-orchestrator IS the GLM mastermind: it does the deep reasoning that
    # decides which workers/models each task needs. Keep it on the GLM-only planner lane (M5,
    # llama-cpp, 1M context) so the brain runs on GLM and the 5090/4070/ollama GPUs stay free for
    # the worker lanes (code/reader/research). Earlier GLM saturation was caused by workers wrongly
    # inheriting the orchestrator model (fixed in menagerie resolveLaneRouteId, commit b0a986cdb),
    # NOT by the orchestrator being on GLM -- so routing it to the coder lane was the wrong fix:
    # it put a coding model on reasoning work and tied up a 5090 slot the code workers need.
    profiles["modeApiConfigs"]["orchestrator"] = "omni-hybrid-planner"
    temporary = path.with_name(path.name + ".native-new")
    with open(temporary, "w", opener=lambda p, flags: os.open(p, flags, 0o600)) as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")
    temporary.replace(path)
    return True

if __name__ == "__main__":
    configure(sys.argv[1], *sys.argv[2:])
