# ESXi  for Nvidia passthroughs / Mac T2 / RPI5 Flakes
* RPI5 flakes please switch to RPI5 branch

# ESXI VM installation guide.
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
1. System will run a script and reboot.
1. 'Command + Option + /' to open the cheatsheet.

# Macland Installation
1. Follow T2 Linux Installation guide First https://wiki.t2linux.org/distributions/nixos/home/
1. Once booted, install git
1. If you cannot get wifi or bluetooth to start, try https://wiki.t2linux.org/guides/wifi-bluetooth/
   1. `nix-shell -p git`
1. Follow the setup guide at https://nixos.wiki/wiki/NixOS_Installation_Guide stop before **NixOS config**
   1. `sudo nixos-generate-config --root /mnt`
   1. `sudo mkdir -p /mnt/sources`
   1. `sudo chown 1000:100 /mnt/sources`
   1. `cd /mnt/sources`
   1. `git clone https://github.com/celesrenata/nix-flakes`
   1. `cp -r nix-flakes/* /mnt/etc/nixos/`
   1. copy the firmware from the previous step to /mnt/etc/nixos/macland/firmware
   1. Consider creating your own branch to track changes from my base code for things like, your username
   1. `sudo nixos-install --root /mnt --flake /mnt/etc/nixos#macland`
   1. `sudo nixos-enter`
   1. `sudo passwd celes`
   1. `sudo poweroff`
1. Login from GDM.
1. System will run a script and reboot.
1. On second reboot, please try to leave it running for however long it takes for http://127.0.0.1:8006 to complete!
1. Once complete, run ~/winapps/runmefirst.sh to setup Office 365
1. run 'command' + 'control' + 'R' to refresh xdg apps from the installation
1. Run 'windows' from spotlight and login to your office 365 account
   * Keep in mind, if any of the winapps do not start, you can run 'windows' to clear the session state, logout, and then run the app'
   * I will look into this! It may need another update from freerdp
  
# Limitations
* Tiny-DFR is looking for keycode 464, howevery keyd resets the keycode to 254, so it doesn't currently work outside of f-keys
