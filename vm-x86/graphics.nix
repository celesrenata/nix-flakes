# Graphics configuration for nixbox (VirtualBox/VMware x86_64 VM)
# VirtualBox exposes VBoxVGA/VMSVGA, VMware exposes vmwgfx.
# Both work with the modesetting driver + mesa.

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

    # VirtualBox VMSVGA and VMware vmwgfx both use modesetting
    services.xserver.videoDrivers = [ "modesetting" ];
  };
}
