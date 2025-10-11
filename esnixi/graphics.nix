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
    version = "580.95.05";
    sha256_64bit = "sha256-hJ7w746EK5gGss3p8RwTA9VPGpp2lGfk5dlhsv4Rgqc=";
    sha256_aarch64 = "";
    openSha256 = "sha256-RFwDGQOi9jVngVONCOB5m/IYKZIeGEle7h0+0yGnBEI=";
    settingsSha256 =  "sha256-F2wmUEaRrpR1Vz0TQSwVK4Fv13f3J9NJLtBe4UP2f14=";
    persistencedSha256 = "sha256-QCwxXQfG/Pa7jSTBB0xD3lsIofcerAWWAHKvWjWGQtg=";
    patches = [ gpl_symbols_linux_615_patch ];
  });
in
{
  nixpkgs.config.allowUnfree = true;
  
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  systemd.services.home-assistant.serviceConfig.DeviceAllow = ["/dev/dri/card0" "/dev/dri/card1"];
  systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;
  services.ollama = {
    enable = true;
    package = pkgs-unstable.ollama;
    host = "0.0.0.0";
    port = 11434;
    acceleration = "cuda";
    models = "/opt/ollama/models";
  };

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
