{ config, lib, pkgs, pkgs-unstable, nixpkgs,  ... }:
{
  config = {
    environment.systemPackages = with pkgs; [
      libGL
    ];
    hardware.graphics =
    with pkgs; {
      enable = true;
      enable32Bit = lib.mkForce false;
      extraPackages = with pkgs; [
        #pkgs-unstable.displaylink
        libva-vdpau-driver
        libvdpau-va-gl
        libGL
      ];
    };
    #chaotic.mesa-git.enable = true;
    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "v3d" ];
  };
}
