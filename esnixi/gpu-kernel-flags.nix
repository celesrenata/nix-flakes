# GPU & Kernel Selection Configuration Module for ESXi (NVIDIA-focused)
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.gpu-selection;
in {

  options.boot.gpu-selection = {
    enableNVIDIA = mkOption {
      type = types.bool;
      default = false;  # Force disabled - use modesetting only for now
      description = "Enable NVIDIA GPU support";
    };
    
    enableROCM = mkOption {
      type = types.bool;
      default = false;  # ROCm is for macland (MacBook T2)
      description = "Enable AMD ROCm support";
    };
  };

  config = mkIf cfg.enableNVIDIA {
    
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia.enable = true;
    hardware.nvidia.open = false;
  } // mkIf cfg.enableROCM {
    
    services.xserver.videoDrivers = [ "amdgpu" ];
    nixpkgs.config.rocmSupport = true;
  };

  # Force disable NVIDIA to prevent auto-detection issues (must be outside conditional blocks)
  hardware.nvidia.enable = lib.mkForce false;

}
