# RPI5 Flakes (they work, the instructions are WIP this time).

## Installation
1. Download the following projects
11. https://github.com/raspberrypi/firmware/tree/master/boot/overlays
11. https://github.com/worproject/rpi5-uefi
11. https://hydra.nixos.org/job/nixos/trunk-combined/nixos.iso_minimal_new_kernel_no_zfs.aarch64-linux
1. Follow nixos instructions to build the USB drive and boot it using ACPI mode.
1. Format an SD card, 3 partitions as GPT
11. Partition 1 - 1gb, uefi
11. Partition 2 - 8gb, swap
11. Partition 3 - 80gb, linux (do not fill the SD card to the max size)
11. `mkfs.fat -F 32 /dev/mmcblk0p1`
11. `mkswap /dev/mmcblk0p2`
11. `mkfs.ext4 /dev/mmcblk0p2`
11. `mount /dev/mmcblk0p2 /mnt`
11. `mkdir /mnt/boot`
11. `mount /dev/mmcblk0p1 /mnt/boot`
11. `nixos-generate-config --root /mnt`
11. `vim /mnt/etc/nixos/configuration.nix`
11.
```
# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.kernelPackages = (import (builtins.fetchTarball https://gitlab.com/vriska/nix-rpi5/-/archive/main.tar.gz)).legacyPackages.aarch64-linux.linuxPackages_rpi5;
  boot.kernelParams = [ "8250.nr_uarts=11" "console=ttyAMA10,9600" "console=tty0" ];
  networking.hostName = "nixberry";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };

  time.timeZone = "America/Los_Angeles";

  environment.systemPackages = with pkgs; [
    vim
    pciutils
    usbutils
    wpa_supplicant
    btop
    curl
    git
  ];

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  networking.firewall.enable = false;
 
  services.hardware.argonone = {
    enable = true;
  };

  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.enlightenment.enable = true;
  };

  system.stateVersion = "24.05"; # Did you read the comment?

}
```
19. `vim /boot/config.txt` ### Your mileage may vary
20.
```
armstub=RPI_EFI.fd
device_tree_address=0x1f0000
device_tree_end=0x210000

# Force 32 bpp framebuffer allocation.
framebuffer_depth=32

# Disable compensation for displays with overscan.
disable_overscan=1

# Force maximum USB power regardless of the power supply.
usb_max_current_enable=1

# Force maximum CPU speed.
# force_turbo=1

# Overclock
over_voltage=delta=50000
arm_freq=2800
gpu_freq=950
armboost=1

# Hardware Interfaces
dtparam=i2c_arm=on
dtparam=pciex1
dtparam=pciex1_gen=3

dtoverlay=vc4-kms-v3d-pi5
```
21. copy the overlay directory you got from raspberrypi's github to boot as `/boot/overlay`
22. nixos-install --root /mnt
23. Go find something else to do for the next 2 hours as it builds

1. Set your password and reboot
1. Break into the UEFI and locate Device Tree mode,
11. Setting it is a bit fiddly, press f10, y, then back out to main page, then press continue to restart with the settings to stick.
1. At this point the system will boot minimally
1. Create a new directory `/tmp/sources`
11. Navigate to that directory.
11. `git clone https://github.com/celesrenata/nix-flakes`
11. `cd nix-flakes`
11. `git checkout rpi5`
11. `cp -r * /etc/nixos/`
11. `mkdir /mnt`
1. Repeat partitioning steps on NVME, if ya got it, otherwise the next step is going to take forever and abuse your SD card. Or if you want even more performance, check out using btrfs on your nvme! https://nixos.wiki/wiki/Btrfs
1. `sudo nixos-install --root /mnt --flake /etc/nixos#nixberry --impure`
1. `nixos-enter --root /mnt`
11. `passwd celes`
11. `exit`
11. `reboot`
11. Login gdm and select hyprland
11. `Use the open file manager to navigate to /home/celes/Backgrounds/ and select the background to complete the setup`
11. press 'command + control + R' to reset AGS
11. click the top right and reboot the Pi.
1. It's ready! Finally...
1. 'Command + Option + /' to open the cheatsheet.
