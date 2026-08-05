# Mini-AI configuration for Nigel
# Stripped-down AI profile: Ollama only, no vLLM, no Open WebUI
# Uses upstream cache packages (not custom-built) to minimize builds
# GTX 950M has 4GB VRAM — suitable for 7B-8B parameter models (Q4/Q5)

{ config, lib, pkgs, pkgsAccel, ... }:

{
  config = lib.mkIf config.my.profiles.ai.enable {
    # ── Ollama user / group ──────────────────────────────────────────────
    users.groups.ollama = {};
    users.users.ollama = {
      isSystemUser = true;
      group = "ollama";
      extraGroups = [ "video" "render" ];
    };

    # ── Ollama service — upstream package, no custom overlays ────────────
    services.ollama = {
      enable = true;
      # Use upstream ollama package from nixpkgs (not pkgsAccel custom build)
      package = lib.mkForce pkgs.ollama;
      host = "0.0.0.0";
      port = 11434;
      modelsDir = "/var/lib/ollama/models";
      syncModels = false;
      # Load small models suitable for 4GB VRAM
      loadModels = [
        "llama3.2:3b"        # 3B parameter — runs well on GTX 950M
        "phi4-mini:3.8b"     # Microsoft's small model
        "snowflake-arctic-embed2"
      ];
      environmentVariables = {
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q4_0";
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_CONTEXT_LENGTH = "8192";
        OLLAMA_KEEP_ALIVE = "300";
        OLLAMA_MAX_QUEUE = "8";
      };
    };

    # Force Ollama service to run as dedicated user (not DynamicUser)
    systemd.services.ollama.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "ollama";
      Group = "ollama";
      ReadWritePaths = [ "/var/lib/ollama/models" ];
    };

    # ── tmpfiles: model directories ──────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d /var/lib/ollama   0755 ollama ollama -"
      "d /var/lib/ollama/models 0775 ollama ollama -"
    ];

    # ── Fix pre-existing ownership on switch ────────────────────────────
    system.activationScripts.fixOllamaModelsPerms = {
      deps = [];
      text = ''
        if [ -d /var/lib/ollama ]; then
          chown -R ollama:ollama /var/lib/ollama
          find /var/lib/ollama -type d -exec chmod u+rwx,g+rx {} +
          find /var/lib/ollama -type f -exec chmod u+rw,g+r {} +
        fi
      '';
    };

    # ── Minimal AI system packages (upstream only) ──────────────────────
    # Override the heavy AI packages from modules/profiles/ai.nix
    environment.systemPackages = lib.mkForce [
      pkgs.ollama
    ];

    # ── Firewall for Ollama ─────────────────────────────────────────────
    networking.firewall.allowedTCPPorts = [ 11434 ];
  };
}
