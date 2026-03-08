{ config, lib, pkgs, pkgs-unstable, ... }:

let
  # NVIDIA package customization (commented out for now)
  # nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
  #   version = "580.105.08";
  #   sha256_64bit = "sha256-2cboGIZy8+t03QTPpp3VhHn6HQFiyMKMjRdiV2MpNHU=";
  # });
in {
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  systemd.services.home-assistant.serviceConfig.DeviceAllow = ["/dev/dri/card0" "/dev/dri/card1"];

  systemd.services.ollama.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "ollama";
    Group = "ollama";
    ReadWritePaths = [ "/opt/ollama/models" ];
  };

  users.groups.ollama = {};
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    extraGroups = [ "video" "render" ];
  };

  systemd.tmpfiles.rules = [
    "d /opt                        0755 root   root   -"
    "d /opt/ollama                0755 ollama ollama -"
    "d /opt/ollama/models         0775 ollama ollama -"
  ];

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
  };

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

  environment.systemPackages = with pkgs; [
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
  
  # Temporarily use modesetting instead of nvidia to avoid build errors
  services.xserver.videoDrivers = [ "modesetting" ];
}
