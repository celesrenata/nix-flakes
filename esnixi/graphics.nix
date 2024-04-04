{ config, pkgs,  ... }:
{
  config = {
    environment.systemPackages = with pkgs; [
      egl-wayland
    ];

    # Enable OpenGL
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [ vaapiVdpau libvdpau-va-gl nvidia-vaapi-driver mesa.drivers ];
    };

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia.modesetting.enable = true;
    hardware.nvidia.powerManagement.enable = false;
    hardware.nvidia.powerManagement.finegrained = false;
    hardware.nvidia.open = true;
    hardware.nvidia.nvidiaSettings = true;
    # Special config to load the latest (535 or 550) driver for the support of the 4070 SUPER
    # hardware.nvidia.package = let
    #   rcu_patch = pkgs.fetchpatch {
    #     url = "https://github.com/gentoo/gentoo/raw/c64caf53/x11-drivers/nvidia-drivers/files/nvidia-drivers-470.223.02-gpl-pfn_valid.patch";
    #     hash = "sha256-eZiQQp2S/asE7MfGvfe6dA/kdCvek9SYa/FFGp24dVg=";
    #   };
    # in
    #   config.boot.kernelPackages.nvidiaPackages.mkDriver {
    #     version = "550.40.07";
    #     sha256_64bit = "sha256-KYk2xye37v7ZW7h+uNJM/u8fNf7KyGTZjiaU03dJpK0=";
    #     sha256_aarch64 = "sha256-AV7KgRXYaQGBFl7zuRcfnTGr8rS5n13nGUIe3mJTXb4=";
    #     openSha256 = "sha256-mRUTEWVsbjq+psVe+kAT6MjyZuLkG2yRDxCMvDJRL1I=";
    #     settingsSha256 = "sha256-c30AQa4g4a1EHmaEu1yc05oqY01y+IusbBuq+P6rMCs=";
    #     persistencedSha256 = "sha256-11tLSY8uUIl4X/roNnxf5yS2PQvHvoNjnd2CB67e870=";

    #     patches = [ rcu_patch ];
    #   };
    hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.vulkan_beta;
  };
}