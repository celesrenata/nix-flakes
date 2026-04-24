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
      acceleration = config.my.acceleration.backend;
      models = config.my.paths.ollamaModels;
      environmentVariables = {
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q4_0";
        OLLAMA_MAX_VRAM = "0.9";
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
    environment.etc."ollama/qwen3-30b-tuned.Modelfile".text = ''
      FROM qwen3:30b
      PARAMETER temperature 0.45
      PARAMETER top_p 0.9
      PARAMETER repeat_penalty 1.08
      PARAMETER num_ctx 262144
    '';

    systemd.services."ollama-create-qwen3-30b-tuned" = {
      after = [ "network-online.target" "ollama.service" ];
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
        ExecStart = (pkgs.writeShellScript "create-qwen3-30b-tuned" ''
          set -euo pipefail
          for i in $(seq 1 30); do
            # treat non-200 as "not ready yet"
            code="$(curl -s -o /dev/null -w '%{http_code}' "$OLLAMA_HOST/api/tags" || true)"
            [ "$code" = "200" ] && break
            sleep 1
          done

          if ! ollama show qwen3:30b >/dev/null 2>&1; then
            ollama pull qwen3:30b
          fi
          if ! ollama show qwen3:30b-tuned >/dev/null 2>&1; then
            ollama create qwen3:30b-tuned -f /etc/ollama/qwen3-30b-tuned.Modelfile
          fi
        '');
      };
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
      vllmPython = pkgsAccel.python312.withPackages (ps: [ pkgsAccel.vllm ]);
      vllmWrapper = pkgs.writeShellScript "vllm-wrapper" ''
        exec ${vllmPython}/bin/python -m vllm.entrypoints.cli.main "$@"
      '';
      cxxWrapper = pkgs.writeShellScriptBin "c++" ''
        exec ${pkgs.gcc}/bin/g++ "$@"
      '';
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
        PYTHONPATH = "${pkgsAccel.vllm}/${pkgsAccel.python312.sitePackages}";
        VLLM_LOGGING_LEVEL = "DEBUG";
        CUDACXX = "${pkgsAccel.cudaPackages.cudatoolkit}/bin/nvcc";
        CXX = "${pkgs.gcc}/bin/g++";
        CC = "${pkgs.gcc}/bin/gcc";
        LIBRARY_PATH = "${pkgsAccel.cudaPackages.cudatoolkit}/lib:${pkgsAccel.cudaPackages.cudatoolkit}/lib/stubs:${config.hardware.nvidia.package}/lib";
      };

      path = [
        pkgs.bash
        pkgs.coreutils
        pkgs.gcc
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
          ${vllmWrapper} serve GadflyII/GLM-4.7-Flash-NVFP4 \
            --host 0.0.0.0 \
            --port 8000 \
            --max-model-len 32768 \
            --gpu-memory-utilization 0.85 \
            --dtype auto
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

      (pkgsAccel.python312.withPackages (ps: with ps; [
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
