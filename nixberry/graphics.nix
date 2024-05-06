{ config, lib, pkgs, pkgs-unstable, nixpkgs,  ... }:
{
  config = {
    # Remote Desktop

    #environment.sessionVariables.LIBVA_DRIVER_NAME = "nvidia";
    #environment.variables.VDPAU_DRIVER = "nvidia";
    systemd.services.home-assistant.serviceConfig.DeviceAllow = ["/dev/dri/card0"];
    # systemd.services."jellyfin".serviceConfig = {
    #   DeviceAllow = pkgs.lib.mkForce [ "char-drm rw" "char-nvidia-frontend rw" "char-nvidia-uvm rw" ];
    #   PrivateDevices = pkgs.lib.mkForce true;
    #   RestrictAddressFamilies = pkgs.lib.mkForce [ "AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6" ];
    # };
    systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;
    services.ollama = {
      enable = true;
      models = "/opt/ollama/models";
    };

    environment.systemPackages = with pkgs-unstable; [
      libGL
      kdenlive
    ];
    hardware.opengl =
    let
      fn = oa: {
        nativeBuildInputs = oa.nativeBuildInputs ++ [ pkgs-unstable.glslang ];
        mesonFlags = oa.mesonFlags ++ [ "-Dvulkan-layers=device-select,overlay" ];
      };
    in
    with pkgs-unstable; {
      enable = true;
      driSupport = true;
      package = (pkgs-unstable.mesa.overrideAttrs fn).drivers;
      extraPackages = with pkgs-unstable; [
        vaapiVdpau
        libvdpau-va-gl
        libGL
      ];
    };

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "v3d" ];
  };
}
