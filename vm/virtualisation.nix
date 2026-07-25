# Virtualisation / Guest services for nixberry (Parallels Desktop aarch64 VM)
# These are guest-side services, not hypervisor services.

{ config, lib, pkgs, ... }:

{
  config = {
    services.spice-webdavd.enable = true;
    services.qemuGuest.enable = true;

    # Shared folder access via WebDAV
    services.davfs2 = {
      enable = true;
      settings = {
        globalSection = {
          ask_auth = "0";
        };
      };
    };

    # Spice tools for clipboard sharing and display resize
    environment.systemPackages = with pkgs; [
      spice
      spice-vdagent
      spice-gtk
    ];
  };
}
