# GPU & Kernel Selection Configuration Module for ESXi (NVIDIA-focused)
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.gpu-selection;
in {

  options.boot.gpu-selection = {
    enableNVIDIA = mkOption {
      type = types.bool;
      default = true;  # Default to NVIDIA for esnixi platform
      description = "Enable NVIDIA GPU support";
    };
    
    enableROCM = mkOption {
      type = types.bool;
      default = false;  # ROCm is for macland (MacBook T2)
      description = "Enable AMD ROCm support";
    };
  };

  config = mkIf cfg.enableNVIDIA {
    
    # Set display driver to NVIDIA when enabled
    services.xserver.videoDrivers = [ "nvidia" ];
    
    # Enable hardware.nvidia module (required for kernel modules)
    hardware.nvidia.enable = true;
    hardware.nvidia.modesetting.enable = false;  # Use proprietary driver instead of modesetting
    hardware.nvidia.open = false;  # Closed-source NVIDIA drivers (better performance/compatibility)
    hardware.nvidia.nvidiaSettings = true;
    hardware.nvidia.powerManagement.enable = true;
    hardware.nvidia.forceFullCompositionPipeline = true;
  } // mkIf cfg.enableROCM {
    
    # Set display driver to AMD GPU when ROCm enabled (for macland)
    services.xserver.videoDrivers = [ "amdgpu" ];
    nixpkgs.config.rocmSupport = true;
  };

}
