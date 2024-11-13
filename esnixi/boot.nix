{ config, lib, pkgs, pkgs-unstable, ... }:
{
  config = {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ntfs" "nfs" ];
      plymouth.enable = true;
      kernelPackages = pkgs.linuxPackages_6_6;
      kernelModules = [ "uinput" "nvidia" ];
      extraModprobeConfig = ''
        options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
        options nvidia NVreg_EnablePCIeGen3=1
        options nvidia NVreg_EnableGpuFirmware=0
        options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerLevel=0x3; PowerMizerDefault=0x3; PowerMizerDefaultAC=0x3"
      '';
      initrd.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];
    };
    hardware.opengl.enable = true;
    virtualisation.spiceUSBRedirection.enable = true;
  };
}
