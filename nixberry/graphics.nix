{ config, lib, pkgs, nixpkgs,  ... }:
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
    #chaotic.mesa-git.enable = true;
    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "v3d" ];
  };
}
