# Boot Configuration for ESXi Baremetal System (NVIDIA temporarily disabled)
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.gpu-selection;
in {
  config = {
    boot = {
      binfmt.emulatedSystems = [ "aarch64-linux" ];
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ntfs" "nfs" ];
      plymouth.enable = true;

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
      
      # NVIDIA kernel modules (conditional based on gpu-selection)
      kernelModules = [ "uinput" "v4l2loopback" ] ++ lib.optional cfg.enableNVIDIA "nvidia";

      # Disable DP-3 at boot to prevent GDM from claiming it
      kernelParams = lib.mkDefault [];

      extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];

      extraModprobeConfig = 
        mkIf cfg.enableNVIDIA ''
          options nvidia_drm modeset=1 fbdev=1
        '';

      # initrd kernel modules (conditional based on gpu-selection)
      initrd.kernelModules = lib.optional cfg.enableNVIDIA "nvidia" ++ 
                           lib.optional cfg.enableNVIDIA "nvidia_modeset" ++
                           lib.optional cfg.enableNVIDIA "nvidia_uvm" ++
                           lib.optional cfg.enableNVIDIA "nvidia_drm";
    };
    # Re-enable hardware.graphics with modesetting (not nvidia)
    hardware.graphics.enable = true;
    services.thermald.enable = true;
  };
}
