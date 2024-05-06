{ config, lib, pkgs, ... }:
{
  config = {
    boot = {
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = false;
        grub.device = "nodev";
        grub.efiSupport = true;
      };
      supportedFilesystems = [ "ext4" "ntfs" "nfs" ];
      kernelPackages = (import (builtins.fetchTarball https://gitlab.com/vriska/nix-rpi5/-/archive/main.tar.gz)).legacyPackages.aarch64-linux.linuxPackages_rpi5;
      kernelParams = [ "8250.nr_uarts=11" "console=ttyAMA10,9660" "console=tty0" ];
      kernelModules = [ "uinput" ];
    };
    hardware.opengl.enable = true;
  };
}
