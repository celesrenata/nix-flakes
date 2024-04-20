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
      btop = {
        cudaSupport = true;
      };
    };
    environment.sessionVariables.LIBVA_DRIVER_NAME = "nvidia";
    environment.variables.VDPAU_DRIVER = "nvidia";
    services.ollama = {
      enable = true;
      acceleration = "cuda";
    };

    environment.systemPackages = with pkgs; [
      libGL
      sunshine
      kdenlive
      nvtopPackages.full
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
    services.xserver.videoDrivers = [ "nvidia" "libcuda" ];
    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      powerManagement.enable = false;
      
      open = true;
      nvidiaSettings = true;
    };
  };
}
