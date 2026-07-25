# Graphics configuration for nixberry (Parallels Desktop aarch64 VM)
# Parallels exposes a virtio-gpu device with Metal-backed 3D acceleration.
# No NVIDIA drivers needed.

{ config, lib, pkgs, ... }:

{
  config = {
    environment.systemPackages = with pkgs; [
      libGL
      mesa-demos
      vulkan-tools
      libva-utils
    ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        libvdpau-va-gl
        libGL
      ];
    };

    # Parallels virtio-gpu uses the default modesetting driver
    services.xserver.videoDrivers = [ "modesetting" ];
  };
}
