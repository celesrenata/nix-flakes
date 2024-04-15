# ESXi Flakes for Nvidia passthroughs
# &
# Mac T2 Flakes

## Installation
1. Boot virtual machine to netboot.xyz
11. Select Linux Network Installs
11. Select Nixos
11. Select Nixos Unstable (or 24.05)
1. Once booted, install git
11. `nix-shell -p git`
1. Follow the setup guide at https://nixos.wiki/wiki/NixOS_Installation_Guide stop before **NixOS config**
11. `sudo nixos-generate-config --root /mnt`
11. `mkdir -p /mnt/sources`
11. `cd /mnt/sources`
11. `git clone https://github.com/celesrenata/nix-flakes`
11. `cp -r nix-flakes/* /mnt/etc/nixos/`
11. Consider creating your own brance to track changes from my base code for things like, your username
11. `sudo nixos-install --root /mnt --flake /mnt/etc/nixos#esnixi`
1. Reboot!
1. `Ctrl + Alt + F7 + F6 + F7 + F1` :)
1. Login as root and setup your user password
1. `pkill gdm`
1. Login as your user, don't forget to select hyprland! englightment is a fallback.
1. 'Command + Control + H' to start a terminal and run initial setup: `.local/bin/initialSetup.sh`
1. 'Command + Option + /' to open the cheatsheet.