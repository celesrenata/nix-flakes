# ESXi  for Nvidia passthroughs / Mac T2 / RPI5 Flakes
* RPI5 flakes please switch to RPI5 branch

## Installation Steps Via Netboot.xyz
* Follow the guide here if you don't use netboot.xyz (https://nixos.org/manual/nixos/unstable/)
1. Boot virtual machine to netboot.xyz
11. Select Linux Network Installs
11. Select Nixos
11. Select Nixos Unstable (or 24.05)
1. Once booted, install git
11. `nix-shell -p git`
1. Follow the setup guide at https://nixos.wiki/wiki/NixOS_Installation_Guide stop before **NixOS config**
11. `sudo nixos-generate-config --root /mnt`
11. `sudo mkdir -p /mnt/sources`
11. `sudo chown 1000:100 /mnt/sources`
11. `cd /mnt/sources`
11. `git clone https://github.com/celesrenata/nix-flakes`
11. `cp -r nix-flakes/* /mnt/etc/nixos/`
11. Consider creating your own brance to track changes from my base code for things like, your username
11. `sudo nixos-install --root /mnt --flake /mnt/etc/nixos#esnixi`
11. `sudo nixos-enter`
11. `sudo passwd celes`
11. `sudo poweroff`
1. Map your video cards pci addresses
1. Boot the virt
1. Login from GDM.
1. System will configure dynamic assets and then reboot for you.
1. 'Command + Option + /' to open the cheatsheet.
