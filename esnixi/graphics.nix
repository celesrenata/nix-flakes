{ config, lib, pkgs, nixpkgs,  ... }:
{
  config = {
    # Remote Desktop
    security.wrappers.sunshine = {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${pkgs.sunshine}/bin/sunshine";
    };
    nixpkgs.config = {
      sunshine = {
        cudaSupport = true;
        cudaCapabilities = [ "12.4" ];
        cudaEnableForwardCompat = true;
        allowUnfree = true;
      };
      btop = {
        cudaSupport = true;
      };
      onnxruntime = {
        cudaSupport = true;
      };
    };

    environment.sessionVariables.LIBVA_DRIVER_NAME = "nvidia";
    environment.variables.VDPAU_DRIVER = "nvidia";
    services.avahi.publish.enable = true;
    services.avahi.publish.userServices = true;
    systemd.services.home-assistant.serviceConfig.DeviceAllow = ["/dev/dri/card0"];
    # systemd.services."jellyfin".serviceConfig = {
    #   DeviceAllow = pkgs.lib.mkForce [ "char-drm rw" "char-nvidia-frontend rw" "char-nvidia-uvm rw" ];
    #   PrivateDevices = pkgs.lib.mkForce true;
    #   RestrictAddressFamilies = pkgs.lib.mkForce [ "AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6" ];
    # };
    systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;
    services.ollama = {
      enable = true;
      acceleration = "cuda";
      models = "/opt/ollama/models";
    };

    environment.systemPackages = with pkgs; [
      libGL
      sunshineOverride
      onnxruntimeOverride
      kdenlive
      nvtopPackages.full
      cudaPackages.cudatoolkit
    ];
    hardware.opengl =
    let
      fn = oa: {
        nativeBuildInputs = oa.nativeBuildInputs ++ [ pkgs.glslang ];
        mesonFlags = oa.mesonFlags ++ [ "-Dvulkan-layers=device-select,overlay" ];
      };
    in
    with pkgs; {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      package = (mesa.overrideAttrs fn).drivers;
      package32 = (pkgsi686Linux.mesa.overrideAttrs fn).drivers;
      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
        nvidia-vaapi-driver
        libGL
        cudaPackages.cudatoolkit
      ];
    };

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.production;
      modesetting.enable = true;
      powerManagement.enable = false;
      
      open = true;
      nvidiaSettings = true;
    };
  };
}
