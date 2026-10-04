# Boot configuration for Nigel (Ryzen AM5 desktop)
# Modern NVIDIA GPU drives Hyprland; AMD IOMMU available for VM passthrough.

{ config, lib, pkgs, ... }:

{
  config = {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ntfs" "nfs" "btrfs" "ext4" "cifs" ];
      plymouth.enable = true;

      # Latest kernel — modern NVIDIA (Turing+/Ada) + AM5 platform support.
      kernelPackages = pkgs.linuxPackages_latest;

      kernelModules = [ "uinput" "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" "kvm-amd" ];

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

      # AMD IOMMU for GPU/device passthrough into VMs (replaces intel_iommu).
      kernelParams = [
        "amd_iommu=on"
        "iommu=pt"
      ];

      extraModprobeConfig = ''
        options nvidia_drm modeset=1 fbdev=1
      '';

      initrd.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];
    };

    hardware.graphics.enable = true;
    services.thermald.enable = lib.mkDefault false;  # thermald is Intel-only
  };
}
