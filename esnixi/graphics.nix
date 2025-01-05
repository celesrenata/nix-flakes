{ config, lib, pkgs, pkgs-unstable, ... }:
let
  # Fixes framebuffer with linux 6.11
  fbdev_linux_611_patch = pkgs.fetchpatch {
    url = "https://patch-diff.githubusercontent.com/raw/NVIDIA/open-gpu-kernel-modules/pull/692.patch";
    hash = "sha256-OYw8TsHDpBE5DBzdZCBT45+AiznzO9SfECz5/uXN5Uc=";
  };
in
rec {
  nixpkgs.config.allowUnfree = true;
  # Remote Desktop
  
  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
  };
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  systemd.services.home-assistant.serviceConfig.DeviceAllow = ["/dev/dri/card0" "/dev/dri/card1"];
  systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;
  services.ollama = {
    enable = true;
    package = pkgs-unstable.ollama;
    #listenAddress = "0.0.0.0:11434";
    host = "0.0.0.0";
    port = 11434;
    acceleration = "cuda";
    models = "/opt/ollama/models";
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 8776;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
    libGL
    nvtopPackages.full
    kdenlive
    immersed
    cudaPackages.cudatoolkit

    # Ollama. 
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
    #driSupport = true;
    #driSupport32Bit = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      libvdpau-va-gl
      libGL
      vulkan-headers
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    #setLdLibraryPath = true;
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    #package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    #  version = "555.52.04";
    #  sha256_64bit = "sha256-nVOubb7zKulXhux9AruUTVBQwccFFuYGWrU1ZiakRAI=";
    #  sha256_aarch64 = "sha256-Kt60kTTO3mli66De2d1CAoE3wr0yUbBe7eqCIrYHcWk=";
    #  openSha256 = "sha256-wDimW8/rJlmwr1zQz8+b1uvxxxbOf3Bpk060lfLKuy0=";
    #  settingsSha256 = "sha256-PMh5efbSEq7iqEMBr2+VGQYkBG73TGUh6FuDHZhmwHk=";
    #  persistencedSha256 = "sha256-KAYIvPjUVilQQcD04h163MHmKcQrn2a8oaXujL2Bxro=";
    #};
    #package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    #  version = "560.35.03";
    #  sha256_64bit = "sha256-8pMskvrdQ8WyNBvkU/xPc/CtcYXCa7ekP73oGuKfH+M=";
    #  sha256_aarch64 = "sha256-s8ZAVKvRNXpjxRYqM3E5oss5FdqW+tv1qQC2pDjfG+s=";
    #  openSha256 = "sha256-/32Zf0dKrofTmPZ3Ratw4vDM7B+OgpC4p7s+RHUjCrg=";
    #  settingsSha256 = "sha256-kQsvDgnxis9ANFmwIwB7HX5MkIAcpEEAHc8IBOLdXvk=";
    #  persistencedSha256 = "sha256-E2J2wYYyRu7Kc3MMZz/8ZIemcZg68rkzvqEwFAL3fFs=";
    #};
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    modesetting.enable = true;
    powerManagement.enable = true;
    forceFullCompositionPipeline = true;
    open = false;
    nvidiaSettings = true;
  };
}
