# Mini-AI configuration for Nigel (Ryzen AM5 + modern NVIDIA GPU)
# Stripped-down AI profile: Ollama only — no vLLM, no TensorRT, no Open WebUI.
# Gated on my.profiles.miniAi.enable so the heavy modules/profiles/ai.nix stack
# (which is gated on my.profiles.ai.enable) stays completely dormant. Uses the
# CUDA-accelerated upstream ollama from pkgsAccel (backend=cuda) for real GPU
# inference without the custom "ai" overlay group build.

{ config, lib, pkgs, pkgsAccel, ... }:

{
  config = lib.mkIf config.my.profiles.miniAi.enable {
    # ── Ollama user / group ──────────────────────────────────────────────
    users.groups.ollama = {};
    users.users.ollama = {
      isSystemUser = true;
      group = "ollama";
      extraGroups = [ "video" "render" ];
    };

    # ── Ollama service — CUDA-accelerated build from pkgsAccel ───────────
    services.ollama = {
      enable = true;
      # CUDA ollama from the accelerator package set (backend=cuda).
      # (CUDA is baked into the package build; the old `acceleration` option
      #  is deprecated — the package variant is authoritative.)
      package = pkgsAccel.ollama;
      host = "0.0.0.0";
      port = 11434;
      modelsDir = config.my.paths.ollamaModels;
      syncModels = false;
      # Model sizes suitable for a modern discrete NVIDIA GPU (8GB+ VRAM).
      loadModels = [
        "qwen2.5:7b"
        "llama3.1:8b"
        "snowflake-arctic-embed2"
      ];
      environmentVariables = {
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0";
        OLLAMA_NUM_PARALLEL = "2";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_CONTEXT_LENGTH = "16384";
        OLLAMA_KEEP_ALIVE = "300";
        OLLAMA_MAX_QUEUE = "16";
      };
    };

    # Force Ollama service to run as dedicated user (not DynamicUser)
    systemd.services.ollama.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "ollama";
      Group = "ollama";
      ReadWritePaths = [ config.my.paths.ollamaModels ];
    };

    # ── tmpfiles: model directories ──────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${config.my.paths.ollamaHome}   0755 ollama ollama -"
      "d ${config.my.paths.ollamaModels} 0775 ollama ollama -"
    ];

    # ── Fix pre-existing ownership on switch ────────────────────────────
    system.activationScripts.fixOllamaModelsPerms = {
      deps = [];
      text = ''
        if [ -d ${config.my.paths.ollamaHome} ]; then
          chown -R ollama:ollama ${config.my.paths.ollamaHome}
          find ${config.my.paths.ollamaHome} -type d -exec chmod u+rwx,g+rx {} +
          find ${config.my.paths.ollamaHome} -type f -exec chmod u+rw,g+r {} +
        fi
      '';
    };

    # ── Minimal AI system packages (ollama only — no heavy ML stack) ────
    environment.systemPackages = [
      pkgsAccel.ollama
    ];

    # ── Firewall for Ollama ─────────────────────────────────────────────
    networking.firewall.allowedTCPPorts = [ 11434 ];
  };
}
