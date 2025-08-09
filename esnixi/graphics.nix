{ config, lib, pkgs, pkgs-unstable, ... }:
let
  # Fixes framebuffer with linux 6.11
  fbdev_linux_611_patch = pkgs.fetchpatch {
    url = "https://patch-diff.githubusercontent.com/raw/NVIDIA/open-gpu-kernel-modules/pull/692.patch";
    hash = "sha256-OYw8TsHDpBE5DBzdZCBT45+AiznzO9SfECz5/uXN5Uc=";
  };
  gpl_symbols_linux_615_patch = pkgs.fetchpatch {
    url = "https://github.com/CachyOS/kernel-patches/raw/914aea4298e3744beddad09f3d2773d71839b182/6.15/misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch";
    hash = "sha256-YOTAvONchPPSVDP9eJ9236pAPtxYK5nAePNtm2dlvb4=";
    stripLen = 1;
    extraPrefix = "kernel/";
  };
#  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
#    version = "570.153.02";
#    sha256_64bit = "sha256-FIiG5PaVdvqPpnFA5uXdblH5Cy7HSmXxp6czTfpd4bY=";
#    sha256_aarch64 = "sha256-FKhtEVChfw/1sV5FlFVmia/kE1HbahDJaxTlpNETlrA=";
#    openSha256 = "sha256-2DpY3rgQjYFuPfTY4U/5TcrvNqsWWnsOSX0f2TfVgTs=";
#    settingsSha256 = "sha256-5m6caud68Owy4WNqxlIQPXgEmbTe4kZV2vZyTWHWe+M=";
#    persistencedSha256 = "sha256-OSo4Od7NmezRdGm7BLLzYseWABwNGdsomBCkOsNvOxA=";
#    patches = [ gpl_symbols_linux_615_patch ];
#  });
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
    version = "575.64.05";
    sha256_64bit = "sha256-hfK1D5EiYcGRegss9+H5dDr/0Aj9wPIJ9NVWP3dNUC0=";
    sha256_aarch64 = "";
    openSha256 = "sha256-mcbMVEyRxNyRrohgwWNylu45vIqF+flKHnmt47R//KU=";
    settingsSha256 = "sha256-o2zUnYFUQjHOcCrB0w/4L6xI1hVUXLAWgG2Y26BowBE=";
    persistencedSha256 = "sha256-2g5z7Pu8u2EiAh5givP5Q1Y4zk4Cbb06W37rf768NFU=";
    patches = [ gpl_symbols_linux_615_patch ];
  });
in
rec {
  nixpkgs.config.allowUnfree = true;
  # Remote Desktop
  
#  security.wrappers.sunshine = {
#    owner = "root";
#    group = "root";
#    capabilities = "cap_sys_admin+p";
#    source = "${pkgs-unstable.sunshine}/bin/sunshine";
#  };
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

  #services.open-webui = {
  #  enable = true;
  #  host = "0.0.0.0";
  #  port = 8776;
  #  openFirewall = true;
  #};

  environment.systemPackages = with pkgs; [
    libGL
    nvtopPackages.full
    kdePackages.kdenlive
    #immersed
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
    package = nvidia-package;
    #package = pkgs-unstable.linuxPackages_6_15.nvidiaPackages;
    #package = pkgs-unstable.linuxPackages_6_15.nvidiaPackages.latest;
    #package = config.boot.kernelPackages.nvidiaPackages.latest;
    modesetting.enable = true;
    powerManagement.enable = true;
    forceFullCompositionPipeline = true;
    open = true;
    nvidiaSettings = true;
  };
}
