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

    # ── Ollama service ───────────────────────────────────────────────────
    services.ollama = {
      enable = true;
      package = pkgsAccel.ollama;
      host = "0.0.0.0";
      port = 11434;
      models = config.my.paths.ollamaModels;
      syncModels = false;
      loadModels = [
        "nutboy02/Qwen3.6-35B-A3B-Claude-4.7-Opus-abliterated-uncenfull:Q2_K_MTX"
      ];
      environmentVariables = {
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q4_0";
        OLLAMA_NUM_PARALLEL = "4";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_CONTEXT_LENGTH = "262144";
        OLLAMA_KEEP_ALIVE = "-1";
        OLLAMA_MAX_QUEUE = "32";
      };
    };

    # Force the Ollama service to run as our dedicated user (not DynamicUser)
    systemd.services.ollama.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "ollama";
      Group = "ollama";
      ReadWritePaths = [ config.my.paths.ollamaModels ];
    };

    # ── Ollama model creation oneshot ────────────────────────────────────
    environment.etc."ollama/qwen3.6-tuned.Modelfile".text = ''
      FROM qwen3.6
      PARAMETER temperature 0.45
      PARAMETER top_p 0.9
      PARAMETER repeat_penalty 1.08
      PARAMETER num_ctx 262144
    '';

    systemd.services."ollama-create-qwen3.6-tuned" = {
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

    # ── vLLM service (CUDA-only) ─────────────────────────────────────────
    systemd.services.vllm = lib.mkIf (config.my.acceleration.backend == "cuda")
    (let
      vllmPython = pkgsAccel.python313.withPackages (ps: [ pkgsAccel.vllm ]);
      vllmWrapper = pkgs.writeShellScript "vllm-wrapper" ''
        exec ${vllmPython}/bin/python -m vllm.entrypoints.cli.main "$@"
      '';
      cxxWrapper = pkgs.writeShellScriptBin "c++" ''
        exec ${pkgs.gcc14}/bin/g++ "$@"
      '';

      # apache-tvm-ffi: full runtime + headers from PyPI (flashinfer 0.6.4+ needs it)
      tvmFfiPkg = pkgs.stdenvNoCC.mkDerivation {
        name = "apache-tvm-ffi-0.1.10";
        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/51/f7/ca3fdadc2468e8b67a2f3f13bb7aa132c584feefd8a25dbf920e4bf0a03b/apache_tvm_ffi-0.1.10-cp312-abi3-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl";
          hash = "sha256-lraQMMciVy4T4wGCczrfotYEJY6Yiz9mMKFvOXx/kog=";
        };
        nativeBuildInputs = [ pkgs.unzip pkgs.autoPatchelfHook ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib ];
        unpackPhase = "unzip $src -d .";
        installPhase = ''
          mkdir -p $out/lib/python3.13/site-packages
          cp -r tvm_ffi apache_tvm_ffi-0.1.10.dist-info $out/lib/python3.13/site-packages/
        '';
      };
    in {
      description = "vLLM OpenAI-compatible API server with NVFP4 support";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        HF_HOME = config.my.paths.vllmModels;
        HOME = config.my.paths.vllmHome;
        VLLM_WORKER_MULTIPROC_METHOD = "spawn";
        HF_TOKEN_PATH = "${config.sops.secrets.huggingface_token.path}";
        CUDA_HOME = "${pkgsAccel.cudaPackages.cudatoolkit}";
        LD_LIBRARY_PATH = "${pkgsAccel.cudaPackages.cudatoolkit}/lib:${pkgsAccel.cudaPackages.cudnn}/lib:${config.hardware.nvidia.package}/lib";
        PYTHONPATH = "${tvmFfiPkg}/lib/python3.13/site-packages:${pkgsAccel.vllm}/${pkgsAccel.python313.sitePackages}";
        VLLM_LOGGING_LEVEL = "DEBUG";
        CUDACXX = "${pkgsAccel.cudaPackages.cudatoolkit}/bin/nvcc";
        CXX = "${pkgs.gcc14}/bin/g++";
        CC = "${pkgs.gcc14}/bin/gcc";
        LIBRARY_PATH = "${pkgsAccel.cudaPackages.cudatoolkit}/lib:${pkgsAccel.cudaPackages.cudatoolkit}/lib/stubs:${config.hardware.nvidia.package}/lib";
      };

      path = [
        pkgs.bash
        pkgs.coreutils
        pkgs.gcc14
        pkgs.binutils
        pkgsAccel.cudaPackages.cudatoolkit
        pkgs.ninja
        pkgs.gnumake
        pkgs.cmake
        cxxWrapper
      ];

      serviceConfig = {
        Type = "simple";
        User = "vllm";
        Group = "vllm";
        ExecStart = ''
          ${vllmWrapper} serve AxionML/Qwen3.5-9B-NVFP4 \
            --host 0.0.0.0 \
            --port 8000 \
            --max-model-len 8192 \
            --gpu-memory-utilization 0.85 \
            --max-num-seqs 8 \
            --enable-prefix-caching \
            --dtype auto \
            --reasoning-parser qwen3 \
            --default-chat-template-kwargs '{"enable_thinking": false}'
        '';
        Restart = "on-failure";
        RestartSec = "10s";
      };
    });

    # ── Firewall for vLLM ────────────────────────────────────────────────
    networking.firewall.allowedTCPPorts = [ 8000 ];

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
      pkgsAccel.vllm
      pkgsAccel.cudaPackages.cudatoolkit

      (pkgsAccel.python313.withPackages (ps: with ps; [
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
