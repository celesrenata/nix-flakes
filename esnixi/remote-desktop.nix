# Remote Desktop Configuration for esnixi
{ config, pkgs, lib, ... }:

{
  # Allow FreeRDP USB redirection for the Microsoft webcam/microphone combo.
  users.groups.freerdp-usb = {};
  users.users.celes.extraGroups = [ "freerdp-usb" ];

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="045e", ATTR{idProduct}=="075d", MODE="0660", GROUP="freerdp-usb", TAG+="uaccess"
  '';

  security.wrappers.xfreerdp = {
    source = "${pkgs.freerdp3Override}/bin/xfreerdp";
    owner = "root";
    group = "freerdp-usb";
    permissions = "u+rx,g+rx,o-rwx";
    capabilities = "cap_dac_override+ep";
  };

  # Enable xrdp service with different port
  services.xrdp = {
    enable = true;
    defaultWindowManager = "${pkgs.xfce4-session}/bin/xfce4-session";
    port = 3390;  # Use different port to avoid conflict with Windows container
  };

  # Enable XFCE
  services.xserver.desktopManager.xfce.enable = true;

  # Required packages
  environment.systemPackages = with pkgs; [
    xfce4-session
    xfdesktop
    xfce4-panel
    thunar
    xfce4-terminal
  ];

  # Open firewall for new port
  networking.firewall.allowedTCPPorts = [ 3390 ];
}
