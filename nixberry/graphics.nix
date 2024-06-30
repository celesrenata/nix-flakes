{ config, lib, pkgs, pkgs-unstable, nixpkgs,  ... }:
{
  config = {
    environment.systemPackages = with pkgs; [
      libGL
      kdenlive
    ];
    hardware.opengl =
    with pkgs; {
      enable = true;
      driSupport = true;
      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
        libGL
      ];
    };
    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "v3d" ];
  };
}
