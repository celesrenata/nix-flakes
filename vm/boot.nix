# Boot configuration for nixberry (Parallels Desktop aarch64 VM)
# Simple systemd-boot, no NVIDIA modules, no custom kernel patches.

{ config, lib, pkgs, ... }:

{
  config = {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = false;
      };
      supportedFilesystems = [ "ext4" "btrfs" "cifs" "ntfs" "nfs" ];
      kernelPackages = pkgs.linuxPackages_latest;
      kernelModules = [ "uinput" ];
      plymouth.enable = true;
    };
    hardware.graphics.enable = true;
  };
}
