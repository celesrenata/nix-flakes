# Graphics configuration for Nigel (Ryzen AM5 desktop)
# Modern NVIDIA GPU (Turing / Ampere / Ada / Blackwell) — primary display + Hyprland.
#
# Modern NVIDIA (Turing GTX 16xx / RTX 20xx and newer) supports the open kernel
# module (nvidia-open) and explicit sync, so Wayland/Hyprland runs cleanly.
# Using the latest production driver with the open module (same as esnixi).

{ config, lib, pkgs, ... }:
let
  # Latest production NVIDIA driver — supports Turing+ and the open kernel module.
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.latest;
in
{
  config = {
    services.avahi.publish.enable = true;
    services.avahi.publish.userServices = true;

    environment.systemPackages = with pkgs; [
      libGL
      nvtopPackages.full
      mesa-demos
      vulkan-tools
      libva-utils
    ];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        libva-vdpau-driver
        libvdpau-va-gl
        libGL
        libgbm
        vulkan-headers
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    };

    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      package = nvidia-package;
      modesetting.enable = true;
      powerManagement.enable = true;
      forceFullCompositionPipeline = true;
      open = true;   # Modern GPU — use the open kernel module (Turing+)
      nvidiaSettings = true;
    };
  };
}
