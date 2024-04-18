{ config, pkgs, nixpkgs,  ... }:
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
      };
    };
    environment.sessionVariables.LIBVA_DRIVER_NAME = "nouveau";
    environment.variables.VDPAU_DRIVER = "nouveau";
    environment.systemPackages = with pkgs; [
      egl-wayland
      libGL
      sunshine
      nvtop
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
      ];
    };

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "nouvaeu" ];
  };
}
