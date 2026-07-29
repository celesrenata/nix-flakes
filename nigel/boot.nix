# Boot configuration for Nigel (Lenovo ideacentre AIO 700-27ISH)
# NVIDIA GTX 950M primary GPU for Hyprland
# Intel HD Graphics 530 passed through to Windows VM

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

      # Use stable kernel for better NVIDIA 950M compatibility
      kernelPackages = pkgs.linuxPackages_latest;

      kernelModules = [ "uinput" "nvidia" "i915" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" ];
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

      extraModprobeConfig = ''
        options nvidia_drm modeset=1 fbdev=1
        # Bind Intel GPU to vfio-pci for VM passthrough
        # Find Intel GPU PCI ID via lspci -nn | grep "VGA" | grep Intel
        # Example: 00:02.0 VGA compatible controller [0300]: Intel Corporation Skylake GT2 [HD Graphics 520] [8086:1912]
        # options vfio-pci ids=8086:1912
      '';

      initrd.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];
    };
    hardware.graphics.enable = true;
  };
}
