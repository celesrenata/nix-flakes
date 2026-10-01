{ config, lib, modulesPath, pkgs, pkgsAccel, ... }:

let
  # This is deliberately one model, for the primary text vLLM service only.
  # The backing NVMe cache remains authoritative; /dev/shm is discarded at boot.
in
{
  config = lib.mkIf config.my.profiles.ai.enable {
    # ── Ollama user / group ──────────────────────────────────────────────
    users.groups.ollama = {};
    users.users.ollama = {
      isSystemUser = true;
      group = "ollama";
      extraGroups = [ "video" "render" ];
    };

    # ── Ollama service ───────────────────────────────────────────────────
    services.ollama = {
      enable = true;
      package = pkgsAccel.ollama;
      host = "0.0.0.0";
      port = 11434;
      modelsDir = config.my.paths.ollamaModels;
      syncModels = false;
      loadModels = [];
      environmentVariables = {
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q4_0";
        OLLAMA_NUM_PARALLEL = "4";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_CONTEXT_LENGTH = "262144";
        OLLAMA_NUM_PREDICT = "-1";
        OLLAMA_KEEP_ALIVE = "300";
        OLLAMA_MAX_QUEUE = "32";
      };
    };

    # Force the Ollama service to run as our dedicated user (not DynamicUser)
    systemd.services.ollama = lib.mkIf config.services.ollama.enable {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "ollama";
        Group = "ollama";
        ReadWritePaths = [ config.my.paths.ollamaModels ];
      };
    };

    # ── Ollama model creation oneshot ────────────────────────────────────
    environment.etc."ollama/qwen3.6-tuned.Modelfile".text = ''
      FROM qwen3.6
      PARAMETER temperature 0.45
      PARAMETER top_p 0.9
      PARAMETER repeat_penalty 1.08
      PARAMETER num_ctx 262144
    '';

    environment.etc."ollama/evocua-32b.Modelfile".text = ''
      FROM /var/lib/ollama/models/evocua/evocua-32b-q4.gguf
      ADAPTER /var/lib/ollama/models/evocua/mmproj.gguf
      PARAMETER stop <|im_end|>
      PARAMETER stop <|endoftext|>
      PARAMETER temperature 0.6
      PARAMETER num_ctx 131072
    '';

    systemd.services."ollama-create-qwen3.6-tuned" = {
      enable = false;
      after = [ "network-online.target" "ollama.service" ];
      wants = [ "network-online.target" ];
      requires = [ "ollama.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "ollama";
        Group = "ollama";
        Environment = [
          "OLLAMA_HOST=http://127.0.0.1:11434"
          "OLLAMA_MODELS=${config.my.paths.ollamaModels}"
          "PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.curl pkgsAccel.ollama pkgs.bash ]}"
        ];
        ExecStart = (pkgs.writeShellScript "create-qwen3.6-tuned" ''
          set -euo pipefail
          for i in $(seq 1 30); do
            # treat non-200 as "not ready yet"
            code="$(curl -s -o /dev/null -w '%{http_code}' "$OLLAMA_HOST/api/tags" || true)"
            [ "$code" = "200" ] && break
            sleep 1
          done

          if ! ollama show qwen3.6 >/dev/null 2>&1; then
            ollama pull qwen3.6
          fi
          if ! ollama show qwen3.6-tuned >/dev/null 2>&1; then
            ollama create qwen3.6-tuned -f /etc/ollama/qwen3.6-tuned.Modelfile
          fi
        '');
      };
    };

    # ── EvoCUA-32B model creation oneshot ─────────────────────────────────
    systemd.services."ollama-create-evocua-32b" = {
      enable = false;
      after = [ "network-online.target" "ollama.service" ];
      wants = [ "network-online.target" ];
      requires = [ "ollama.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "ollama";
        Group = "ollama";
        Environment = [
          "OLLAMA_HOST=http://127.0.0.1:11434"
          "OLLAMA_MODELS=${config.my.paths.ollamaModels}"
          "PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.curl pkgsAccel.ollama pkgs.bash ]}"
        ];
        ExecStart = (pkgs.writeShellScript "create-evocua-32b" ''
          set -euo pipefail
          for i in $(seq 1 30); do
            code="$(curl -s -o /dev/null -w '%{http_code}' "$OLLAMA_HOST/api/tags" || true)"
            [ "$code" = "200" ] && break
            sleep 1
          done

          # Only create if the GGUF source exists and model needs refresh
          if [ -f /var/lib/ollama/models/evocua/evocua-32b-q4.gguf ]; then
            ollama create evocua-32b -f /etc/ollama/evocua-32b.Modelfile
          fi
        '');
      };
    };

    # ── Qwen 3.6 Opus 4×256K alias (Modelfile + oneshot) ────────────────
    systemd.services.ollama-qwen36-opus-profile =
      let
        ollamaExe = lib.getExe config.services.ollama.package;
        qwenModelfile = pkgs.writeText "qwen36-opus-4x-256k.Modelfile" ''
          FROM nutboy02/Qwen3.6-35B-A3B-Claude-4.7-Opus-abliterated-uncenfull:Q2_K_MTX

          PARAMETER num_ctx 262144
          PARAMETER num_batch 64
          PARAMETER num_predict 8192
        '';
      in {
        enable = false;
        description = "Create the Qwen 3.6 Opus 4×256K Ollama profile";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "ollama.service"
          "ollama-model-loader.service"
        ];
        requires = [ "ollama.service" ];

        environment = {
          OLLAMA_HOST = "${config.services.ollama.host}:${toString config.services.ollama.port}";
          OLLAMA_MODELS = config.my.paths.ollamaModels;
          OLLAMA_ORIGINS = "*";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "ollama";
          Group = "ollama";
        };

        script = ''
          set -euo pipefail

          # Wait for Ollama API to be ready (up to 120s)
          for attempt in $(seq 1 60); do
            if ${pkgs.curl}/bin/curl \
              --fail \
              --silent \
              "http://${config.services.ollama.host}:${toString config.services.ollama.port}/api/version" \
              >/dev/null; then
              break
            fi

            if [ "$attempt" -eq 60 ]; then
              echo "ERROR: Ollama did not become ready within 120s"
              exit 1
            fi

            sleep 2
          done

          # Verify source model is present
          if ! ${ollamaExe} show \
            "nutboy02/Qwen3.6-35B-A3B-Claude-4.7-Opus-abliterated-uncenfull:Q2_K_MTX" \
            >/dev/null 2>&1; then
            echo "ERROR: Source model Q2_K_MTX not found. Waiting for model-loader..."
            exit 1
          fi

          # Create or refresh the alias
          echo "Creating qwen36-opus-4x-256k alias..."
          ${ollamaExe} create \
            qwen36-opus-4x-256k \
            -f ${qwenModelfile}

          echo "Alias qwen36-opus-4x-256k created successfully."
        '';
      };

    # ── Preload qwen36-opus-4x-256k into VRAM ───────────────────────────
    systemd.services.ollama-preload-qwen36-opus = {
      enable = false;
      description = "Preload qwen36-opus-4x-256k into GPU VRAM";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "ollama.service"
        "ollama-qwen36-opus-profile.service"
      ];
      requires = [ "ollama.service" "ollama-qwen36-opus-profile.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "ollama";
        Group = "ollama";
      };

      script = ''
        set -euo pipefail

        # Send a minimal request to load the model with keep_alive=-1
        echo "Preloading qwen36-opus-4x-256k into VRAM..."
        ${pkgs.curl}/bin/curl \
          --silent \
          --show-error \
          --fail \
          --max-time 300 \
          "http://${config.services.ollama.host}:${toString config.services.ollama.port}/api/chat" \
          --header 'Content-Type: application/json' \
          --data '{"model":"qwen36-opus-4x-256k","messages":[{"role":"user","content":"hi"}],"stream":false,"keep_alive":-1}' \
          >/dev/null

        echo "Model preloaded and pinned in VRAM (keep_alive=-1)."
      '';
    };

    # ── vLLM user / group ────────────────────────────────────────────────
    users.groups.vllm = {};
    users.users.vllm = {
      isSystemUser = true;
      group = "vllm";
      extraGroups = [ "video" "render" ];
    };

    # ── HuggingFace token (sops) ─────────────────────────────────────────
    sops.secrets.huggingface_token = {
      sopsFile = ../../secrets/secrets.yaml;
      owner = "vllm";
      group = "vllm";
    };

    # Vision-language lift for Arcane Atlas.  This stays on loopback: only the
    # queue worker may submit reference images.  The shared idle middleware
    # moves weights off the 5090 when idle and releases the same lease Comfy
    # and the primary text vLLM service use.
    virtualisation.oci-containers.containers.vllm-vision-5090 = {
      autoStart = false;
      image = "vllm/vllm-openai:v0.29.0@sha256:c2914767605584b6d8f45686b82de173ecc99e781897aa3d0a66dacd72c51ae1";
      entrypoint = "python3";
      volumes = [
        "${config.my.paths.vllmModels}:/root/.cache/huggingface"
        "${config.sops.secrets.huggingface_token.path}:/run/secrets/huggingface_token:ro"
        "${import ../../esnixi/gpu-runtime.nix { inherit pkgs; }}:/opt/vllm-idle:ro"
        "/run/arcane-gpu:/run/arcane-gpu"
      ];
      ports = [ "127.0.0.1:8011:8000" ];
      environment = {
        PYTHONPATH = "/opt/vllm-idle";
        HF_HOME = "/root/.cache/huggingface";
        HF_TOKEN_PATH = "/run/secrets/huggingface_token";
        PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";
        VLLM_WORKER_MULTIPROC_METHOD = "spawn";
        # Keep the 5090 warm through normal agent turns.  A five-second sleep
        # interval races with OmniRoute health checks and produces false
        # network/unavailable failures.
        VLLM_IDLE_SECONDS = "300";
        ARCANE_GPU_LOCK = "/run/arcane-gpu/5090.lock";
      };
      cmd = [
        "/opt/vllm-idle/gpu_launch.py" "vllm" "serve"
        "Qwen/Qwen2.5-VL-7B-Instruct"
        "--served-model-name" "qwen2.5-vl-7b-instruct"
        "--host" "0.0.0.0"
        "--port" "8000"
        "--max-model-len" "8192"
        "--gpu-memory-utilization" "0.65"
        # This is an on-demand contract reviewer, not a throughput service.
        # Eager mode avoids a lengthy CUDA-graph capture on the shared 5090.
        "--enforce-eager"
        "--max-num-seqs" "2"
        "--max-num-batched-tokens" "8192"
        "--limit-mm-per-prompt" ''{"image": 8}''
        "--enable-chunked-prefill"
        "--enable-prefix-caching"
        "--enable-sleep-mode"
        "--api-server-count" "1"
        "--middleware" "vllm_idle.IdleSleepMiddleware"
      ];
      extraOptions = [
        "--device=nvidia.com/gpu=all"
        "--ipc=host"
      ];
    };

    systemd.services.vllm-nvidia-cdi =
      let
        generator = pkgs.callPackage
          "${modulesPath}/services/hardware/nvidia-container-toolkit/cdi-generate.nix"
          {
            inherit (config.hardware.nvidia-container-toolkit)
              csv-files
              device-name-strategy
              discovery-mode
              mounts
              disable-hooks
              enable-hooks
              extraArgs;
            nvidia-container-toolkit = config.hardware.nvidia-container-toolkit.package;
            nvidia-driver = config.hardware.nvidia.package;
          };
      in
      {
        description = "Generate NVIDIA CDI metadata for the vLLM container";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "cdi";
          RemainAfterExit = true;
          ExecStartPre = "-${lib.getExe' pkgs.systemd "udevadm"} settle --timeout=180";
          ExecStart = lib.getExe generator;
        };
      };

    systemd.services.docker-vllm-vision-5090 = {
      after = [ "arcane-gpu-lock.service" "vllm-nvidia-cdi.service" ];
      requires = [ "arcane-gpu-lock.service" "vllm-nvidia-cdi.service" ];
      conflicts = [ "ollama.service" ];
    };

    # ── Firewall for vLLM ────────────────────────────────────────────────
    networking.firewall.allowedTCPPorts = [ 8010 ];

    # ── Open WebUI ───────────────────────────────────────────────────────
    services.open-webui = {
      enable = true;
      port = 8776;
    };

    # ── tmpfiles: model directories ──────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${config.my.paths.ollamaHome}   0755 ollama ollama -"
      "d ${config.my.paths.ollamaModels} 0775 ollama ollama -"
      "d ${config.my.paths.vllmHome}     0755 vllm   vllm   -"
      "d ${config.my.paths.vllmModels}   0775 vllm   vllm   -"
    ];

    # ── Fix pre-existing ownership on switch ─────────────────────────────
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

    # ── AI system packages (from pkgsAccel) ──────────────────────────────
    environment.systemPackages = [
      pkgsAccel.cudaPackages.cudatoolkit

      (pkgsAccel.python3.withPackages (ps: with ps; [
        torchvision
        torchaudio
        torch
        diffusers
        transformers
        accelerate
      ]))
    ];
  };
}
