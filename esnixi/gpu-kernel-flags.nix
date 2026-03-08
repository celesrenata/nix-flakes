# GPU & Kernel Selection Configuration Module for ESXi (NVIDIA disabled)
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.gpu-selection;
in {

  options.boot.gpu-selection = {
    enableNVIDIA = mkOption {
      type = types.bool;
      default = false;  # Disabled for now - use modesetting only
      description = "Enable NVIDIA GPU support";
    };
    
    enableROCM = mkOption {
      type = types.bool;
      default = false;  # ROCm is for macland (MacBook T2)
      description = "Enable AMD ROCm support";
    };
  };

  config = {
    services.xserver.videoDrivers = [ "modesetting" ];
    
    nixpkgs.config.rocmSupport = cfg.enableROCM;
  } // mkIf cfg.enableNVIDIA {
    # NVIDIA configuration (currently disabled by default)
    services.xserver.videoDrivers = [ "nvidia" ];
  };

}
