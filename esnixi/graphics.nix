{ config, lib, pkgs, pkgs-unstable, ... }:
let
  # 6.16 compatibility patch for vm_flags
  gpl_symbols_linux_615_patch = pkgs.fetchpatch {
    url = "https://github.com/CachyOS/kernel-patches/raw/914aea4298e3744beddad09f3d2773d71839b182/6.15/misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch";
    hash = "sha256-YOTAvONchPPSVDP9eJ9236pAPtxYK5nAePNtm2dlvb4=";
    stripLen = 1;
    extraPrefix = "kernel/";
  };
  
  # Custom NVIDIA package with 580 drivers and 6.16 patches
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
    version = "580.105.08";
    sha256_64bit = "sha256-2cboGIZy8+t03QTPpp3VhHn6HQFiyMKMjRdiV2MpNHU=";
    sha256_aarch64 = "";
    openSha256 = "sha256-FGmMt3ShQrw4q6wsk8DSvm96ie5yELoDFYinSlGZcwQ=";
    settingsSha256 = "sha256-YvzWO1U3am4Nt5cQ+b5IJ23yeWx5ud1HCu1U0KoojLY=";
    persistencedSha256 = "";
  });
in
{
  nixpkgs.config.allowUnfree = true;
  
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

  environment.systemPackages = with pkgs; [
    libGL
    nvtopPackages.full
    kdePackages.kdenlive
    cudaPackages.cudatoolkit

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
      vaapiVdpau
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
