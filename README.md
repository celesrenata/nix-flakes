# ESXi  for Nvidia passthroughs / Mac T2 / RPI5 Flakes
* RPI5 flakes please switch to RPI5 branch

## Installation Steps Via Netboot.xyz
* Follow the guide here if you don't use netboot.xyz (https://nixos.org/manual/nixos/unstable/)
1. Boot virtual machine to netboot.xyz
   1. Select Linux Network Installs
   1. Select Nixos
   1. Select Nixos Unstable (or 24.05)
1. Once booted, install git
   1. `nix-shell -p git`
1. Follow the setup guide at https://nixos.wiki/wiki/NixOS_Installation_Guide stop before **NixOS config**
   1. `sudo nixos-generate-config --root /mnt`
   1. `sudo mkdir -p /mnt/sources`
   1. `sudo chown 1000:100 /mnt/sources`
   1. `cd /mnt/sources`
   1. `git clone https://github.com/celesrenata/nix-flakes`
   1. `cp -r nix-flakes/* /mnt/etc/nixos/`
   1. Consider creating your own branch to track changes from my base code for things like, your username
   1. `sudo nixos-install --root /mnt --flake /mnt/etc/nixos#esnixi`
   1. `sudo nixos-enter`
   1. `sudo passwd celes`
   1. `sudo poweroff`
1. Map your video cards pci addresses
1. disable svga head from virtual machine (mostly to not confuse the OS)
1. Boot the virt
1. Login from GDM.
1. System will enter a preconfigured state
   1. 'Control + Q'
   1. `.local/bin/initialSetup`
      * This will create a state file in `~/.local/share/initialSetup` if you delete this and rerun initial setup you will be able to pull the latest settings into `~/.config` if you run into problems.
1. 'Command + Option + /' to open the cheatsheet.
