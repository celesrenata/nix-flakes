{ config, lib, pkgs, ... }:
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
    version = "595.91.07";
    sha256_64bit = "sha256-yiPIjdJLB6GRZE4eEc+3vN11NzBXSa9A+YABiwleYxM=";
    sha256_aarch64 = "";
    openSha256 = "sha256-OB8Epd+qn/WywxsPiFpxEOAzlJqb6I1SyRoV3a8l71k=";
    settingsSha256 = "sha256-QzT8Cw1luuZGP9DUje3HN/0ngiayqHURj+bqPsxlJ5w=";
    persistencedSha256 = "sha256-3JQBaNmkwxvCXv9q8aHKas6VZM/JjLsuilC2t7ET0u0=";
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
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  systemd.services.home-assistant.serviceConfig.DeviceAllow = ["/dev/dri/card0" "/dev/dri/card1"];

  environment.systemPackages = with pkgs; [
    libGL
    nvtopPackages.full
  ];
  
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-vdpau-driver
      libvdpau-va-gl
      libGL
      libgbm
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
