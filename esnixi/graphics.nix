{ config, lib, pkgs, pkgs-unstable, ... }:
let
  # 6.16 compatibility patch for vm_flags
  #gpl_symbols_linux_615_patch = pkgs.fetchpatch {
  #  url = "https://github.com/CachyOS/kernel-patches/raw/914aea4298e3744beddad09f3d2773d71839b182/6.15/misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch";
  #  hash = "sha256-YOTAvONchPPSVDP9eJ9236pAPtxYK5nAePNtm2dlvb4=";
  #  stripLen = 1;
  #  extraPrefix = "kernel/";
  #};
  
  # Custom NVIDIA package with 580 drivers and 6.16 patches
  #base-nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
    version = "580.126.09";
    sha256_64bit = "sha256-TKxT5I+K3/Zh1HyHiO0kBZokjJ/YCYzq/QiKSYmG7CY=";
    sha256_aarch64 = "";
    openSha256 = "sha256-ychsaurbQ2KNFr/SAprKI2tlvAigoKoFU1H7+SaxSrY=";
    settingsSha256 = "sha256-4SfCWp3swUp+x+4cuIZ7SA5H7/NoizqgPJ6S9fm90fA=";
    persistencedSha256 = "";
  });

  #nvidia-package = base-nvidia-package // {
  #  open = base-nvidia-package.open.overrideAttrs (openAttrs: {
  #    postPatch = (openAttrs.postPatch or "") + ''
  #      substituteInPlace kernel-open/nvidia-uvm/uvm_va_range_device_p2p.c \
  #        --replace 'get_dev_pagemap(page_to_pfn(page), NULL)' 'get_dev_pagemap(page_to_pfn(page))'
  #    '';
  #  });
  #};
in
{
  # nixpkgs.config.allowUnfree = true;
  
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  systemd.services.home-assistant.serviceConfig.DeviceAllow = ["/dev/dri/card0" "/dev/dri/card1"];
# Make sure the service runs as an actual user we control
  systemd.services.ollama.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "ollama";
    Group = "ollama";
    # (optional but nice) tighten the service to the models path
    ReadWritePaths = [ "/opt/ollama/models" ];
  };

  users.groups.ollama = { };
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    extraGroups = [ "video" "render" ];
  };

  # Ensure the full path is traversable (execute bit) and writable by ollama
  systemd.tmpfiles.rules = [
    # parent
    "d /opt                        0755 root   root   -"
    # repo root for models
    "d /opt/ollama                0755 ollama ollama -"
    # actual model store (group-writable okay; adjust to 0750 if you prefer)
    "d /opt/ollama/models         0775 ollama ollama -"
    # vLLM directories
    "d /opt/vllm                  0755 vllm vllm -"
    "d /opt/vllm/models           0775 vllm vllm -"
  ];

  # One-time guard: fix pre-existing ownership/permissions on switch
  system.activationScripts.fixOllamaModelsPerms = {
    deps = [ ];
    text = ''
      if [ -d /opt/ollama ]; then
        chown -R ollama:ollama /opt/ollama
        # ensure every directory is traversable by owner/group
        find /opt/ollama -type d -exec chmod u+rwx,g+rx {} +
        # files at least readable by owner/group
        find /opt/ollama -type f -exec chmod u+rw,g+r {} +
      fi
    '';
  };

  # Your Modelfile as-is
  environment.etc."ollama/qwen3-30b-tuned.Modelfile".text = ''
    FROM qwen3:30b
    PARAMETER temperature 0.45
    PARAMETER top_p 0.9
    PARAMETER repeat_penalty 1.08
    PARAMETER num_ctx 262144
  '';

  services.ollama = {
    enable = true;
    package = pkgs-unstable.ollama;
    host = "0.0.0.0";
    port = 11434;
    acceleration = "cuda";
    models = "/opt/ollama/models";
    environmentVariables = {
      OLLAMA_NUM_PARALLEL = "1";
      OLLAMA_MAX_LOADED_MODELS = "1";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q4_0";
      OLLAMA_MAX_VRAM = "0.9";
    };
    # leave loadModels commented so nothing pre-warms
    # loadModels = [ "qwen3:30b" ];
  };

  # Keep your oneshot; no functional change needed
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
        "OLLAMA_MODELS=/opt/ollama/models"
        "PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.curl pkgs-unstable.ollama pkgs.bash ]}"
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
# services.ollama = {
#     enable = true;
#     package = pkgs-unstable.ollama;
#     host = "0.0.0.0";
#     port = 11434;
#     acceleration = "cuda";
#     models = "/opt/ollama/models";
#     environmentVariables = {
#       OLLAMA_NUM_PARALLEL = "1";
#       OLLAMA_MAX_LOADED_MODELS = "1";
#       OLLAMA_FLASH_ATTENTION = "1";
#       OLLAMA_KV_CACHE_TYPE = "q4_0";
#       OLLAMA_MAX_VRAM = "0.9";
#     };
#    loadModels = [ "qwen3:30b" ];
#  };

  # vLLM service with NVFP4 support
  users.groups.vllm = { };
  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    extraGroups = [ "video" "render" ];
  };

  sops.secrets.huggingface_token = {
    sopsFile = ../secrets/secrets.yaml;
    owner = "vllm";
    group = "vllm";
  };

  systemd.services.vllm = 
  let
    vllmPython = pkgs.python312.withPackages (ps: [ pkgs.vllm ]);
    vllmWrapper = pkgs.writeShellScript "vllm-wrapper" ''
      exec ${vllmPython}/bin/python -m vllm.entrypoints.cli.main "$@"
    '';
    # Create a wrapper that provides c++ command
    cxxWrapper = pkgs.writeShellScriptBin "c++" ''
      exec ${pkgs.gcc}/bin/g++ "$@"
    '';
  in {
    description = "vLLM OpenAI-compatible API server with NVFP4 support";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      HF_HOME = "/opt/vllm/models";
      HOME = "/opt/vllm";
      VLLM_WORKER_MULTIPROC_METHOD = "spawn";
      HF_TOKEN_PATH = "${config.sops.secrets.huggingface_token.path}";
      CUDA_HOME = "${pkgs.cudaPackages.cudatoolkit}";
      LD_LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib:${config.hardware.nvidia.package}/lib";
      PYTHONPATH = "${pkgs.vllm}/${pkgs.python312.sitePackages}";
      VLLM_LOGGING_LEVEL = "DEBUG";
      CUDACXX = "${pkgs.cudaPackages.cudatoolkit}/bin/nvcc";
      CXX = "${pkgs.gcc}/bin/g++";
      CC = "${pkgs.gcc}/bin/gcc";
      LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudatoolkit}/lib/stubs:${config.hardware.nvidia.package}/lib";
    };
    
    path = [ 
      pkgs.bash
      pkgs.coreutils
      pkgs.gcc 
      pkgs.binutils 
      pkgs.cudaPackages.cudatoolkit 
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
  };

  networking.firewall.allowedTCPPorts = [ 8000 ];

  environment.systemPackages = with pkgs; [
    libGL
    nvtopPackages.full
    kdePackages.kdenlive
    cudaPackages.cudatoolkit
    pkgs.vllm

    (python312.withPackages(ps: with ps; [
      torchvision
      torchaudio
      torch
      diffusers
      transformers
      accelerate
    ]))
  ];
  
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-vdpau-driver
      libvdpau-va-gl
      libGL
      vulkan-headers
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = nvidia-package;
    modesetting.enable = true;
    powerManagement.enable = true;
    forceFullCompositionPipeline = true;
    open = true;
    nvidiaSettings = true;
  };
}
