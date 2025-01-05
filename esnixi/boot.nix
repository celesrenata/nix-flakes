{ config, lib, pkgs, pkgs-unstable, ... }:
{
  config = {
    nixpkgs.config.allowUnsupportedSystem = true;
    boot = {
      #binfmt.emulatedSystems = [ "aarch64-linux" ];
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ntfs" "nfs" ];
      plymouth.enable = true;
      kernelPackages = pkgs.linuxPackages_latest;
      kernelPatches = [
        {
          name = "amdgpu-ignore-ctx-privileges";
          patch = pkgs.fetchpatch {
            name = "cap_sys_nice_begone.patch";
            url = "https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
            hash = "sha256-Y3a0+x2xvHsfLax/uwycdJf3xLxvVfkfDVqjkxNaYEo=";
          };
        }
      ];
      kernelModules = [ "uinput" "nvidia" "v4l2loopback" ];
      extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
      extraModprobeConfig = ''
         options nvidia_drm modeset=1 fbdev=1
      '';
       # options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1; PerfLevelSrc=0x2222; PowerMizerLevel=0x3; PowerMizerDefault=0x3; PowerMizerDefaultAC=0x3"
       # options nvidia NVreg_OpenRmEnableUnsupportedGpus=1
       # options nvidia NVreg_EnablePCIeGen3=1
       # options nvidia NVreg_EnableGpuFirmware=0
      initrd.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];
    };
    hardware.graphics.enable = true;
#    virtualisation.spiceUSBRedirection.enable = true;
  };
}
