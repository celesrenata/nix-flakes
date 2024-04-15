{ lib, pkgs, ... }:
{
  options.vfio.enable = with lib;
    mkEnableOption "Configure the machine for VFIO";

  config = {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ntfs" "nfs" ];
      plymouth.enable = true;
      kernelPackages = pkgs.linuxPackages_latest;
      kernelModules = [ "uinput" "nvidia" ];
      extraModprobeConfig = ''
        options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
        options nvidia NVreg_EnablePCIeGen3=1
        options nvidia NVreg_EnableGpuFirmware=0
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
