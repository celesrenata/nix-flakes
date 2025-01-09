{ config, lib, pkgs, pkgs-unstable, nixpkgs,  ... }:
{
  config = {
    environment.systemPackages = with pkgs; [
      libGL
      kdenlive
    ];
    hardware.graphics =
    with pkgs; {
      enable = true;
      extraPackages = with pkgs; [
        #pkgs-unstable.displaylink
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
