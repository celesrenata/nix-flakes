# GPU & Kernel Selection Configuration Module
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.gpu-selection;
in {

  options.boot.gpu-selection = {
    enableNVIDIA = mkOption {
      type = types.bool;
      default = false;
      description = "Enable NVIDIA GPU support";
    };
    
    enableROCM = mkOption {
      type = types.bool;
      default = true;
      description = "Enable AMD ROCm support";
    };
  };

  config = mkIf (cfg.enableNVIDIA || cfg.enableROCM) {
    
    # Set display driver based on GPU type
    services.xserver.videoDrivers = mkDefault (
      if cfg.enableNVIDIA then [ "nvidia" ]
      else if cfg.enableROCM then [ "amdgpu" ]
      else []
    );
  };

}
