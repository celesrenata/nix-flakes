# Boot Configuration for ESXi Baremetal System
{ config, lib, pkgs, ... }:

{
  config = {
    boot = {
      binfmt.emulatedSystems = [ "aarch64-linux" ];
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ntfs" "nfs" ];
      plymouth.enable = true;

      # Using default kernel (commented out custom linux_6.17 which reached EOL)
      # kernelPackages = myKernelPackages;

      kernelPatches = lib.mkDefault [
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

      # Disable DP-3 at boot to prevent GDM from claiming it
      kernelParams = lib.mkDefault [];

      # Use whatever v4l2loopback package you want, or comment if handled via kernelPackages
      extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];

      extraModprobeConfig = ''
        options nvidia_drm modeset=1 fbdev=1
      '';

      # initrd kernel modules
      initrd.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];
    };
    hardware.graphics.enable = true;
    services.thermald.enable = true;
  };
}
