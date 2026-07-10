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
    version = "595.84";
    sha256_64bit = "sha256-mcQE5SExvye8ptoCaNzOPr7cenOrF0BxqZXPGmxeugY=";
    sha256_aarch64 = "";
    openSha256 = "sha256-pEmA2tUcOKwUPKy6N0QvS49Pdut4/7Phs/JhjdyBcNY=";
    settingsSha256 = "sha256-QrnBM+sdWO4GanO62rxpHmRrjYkYpl5RD6fIiHq4C4A=";
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
