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
    # Force disable NVIDIA to prevent auto-detection issues
    hardware.nvidia.enable = lib.mkForce false;
    
    services.xserver.videoDrivers = [ "modesetting" ];
    
    nixpkgs.config.rocmSupport = cfg.enableROCM;
  } // mkIf cfg.enableNVIDIA {
    # This won't be reached due to mkForce above, but kept for completeness
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia.enable = true;
  };

}
