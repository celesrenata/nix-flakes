# Graphics configuration for Nigel (Lenovo ideacentre AIO 700-27ISH)
# NVIDIA GeForce GTX 950M — primary display + Hyprland compositor
# Intel HD Graphics 530 — reserved for Windows VM passthrough
#
# GTX 950M is Maxwell (GM107). Maxwell is supported by the 470xx driver series.
# Maxwell is NOT supported by the open kernel module (nvidia-open) — that's Turing+.
# Maxwell lacks explicit sync support (pre-555 drivers), so Hyprland may have
# flickering in XWayland. Using proprietary 470xx driver.

{ config, lib, pkgs, ... }:
let
  # GTX 950M (Maxwell GM107) — last driver: 470.256.56 (470xx series)
  # Use nixpkgs' nvidiaPackages.legacy_470 (or stable) which provides 470xx drivers
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.legacy_470;
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
      open = false;  # Maxwell requires proprietary driver — no open kernel module
      nvidiaSettings = true;
    };
  };
}
