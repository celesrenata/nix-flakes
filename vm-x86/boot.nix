# Boot configuration for nixbox (VirtualBox/VMware x86_64 VM)
# Simple systemd-boot, no NVIDIA modules, no custom kernel patches.

{ config, lib, pkgs, ... }:

{
  config = {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      supportedFilesystems = [ "ext4" "btrfs" "cifs" "ntfs" "nfs" ];
      kernelPackages = pkgs.linuxPackages_latest;
      kernelModules = [ "uinput" ];
      plymouth.enable = true;
    };
    hardware.graphics.enable = true;
  };
}
