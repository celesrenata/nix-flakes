{ config, lib, pkgs, nixpkgs, ... }:
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
      btop = {
        cudaSupport = true;
      };
      onnxruntime = {
        cudaSupport = true;
      };
    };

    services.avahi.publish.enable = true;
    services.avahi.publish.userServices = true;
    systemd.services.home-assistant.serviceConfig.DeviceAllow = ["/dev/dri/card0"];
    systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;
    services.ollama = {
      enable = true;
      acceleration = "cuda";
      models = "/opt/ollama/models";
    };

    environment.systemPackages = with pkgs; [
      libGL
      onnxruntimeOverride
      kdenlive
      nvtopPackages.full
      cudaPackages.cudatoolkit
    ];
    hardware.opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      extraPackages = with pkgs; [
        vaapiVdpau
        libvdpau-va-gl
        libGL
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
      setLdLibraryPath = true;
    };

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
      powerManagement.enable = false;
      
      open = true;
      nvidiaSettings = true;
    };
  };
}
