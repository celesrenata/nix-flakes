# Remote Desktop Configuration for esnixi
{ config, pkgs, lib, ... }:

{
  # Enable xrdp service with different port
  services.xrdp = {
    enable = true;
    defaultWindowManager = "${pkgs.xfce.xfce4-session}/bin/xfce4-session";
    port = 3390;  # Use different port to avoid conflict with Windows container
  };

  # Enable XFCE
  services.xserver.desktopManager.xfce.enable = true;

  # Required packages
  environment.systemPackages = with pkgs; [
    xfce.xfce4-session
    xfce.xfdesktop
    xfce.xfce4-panel
    xfce.thunar
    xfce.xfce4-terminal
  ];

  # Open firewall for new port
  networking.firewall.allowedTCPPorts = [ 3390 ];
}
