# GPU & Kernel Selection Configuration
{ config, lib, pkgs, ... }:

let
  # ============================================================================
  # GPU SELECTION (Choose ONE)
  # ============================================================================
  
  enableNVIDIA = false;
  enableROCM = true;
  
  # ============================================================================
  # KERNEL VERSION SELECTION
  # Options: "latest", "6_12", "6_18", "6_19"
  # ============================================================================
  
  kernelVersion = "latest";
  
  selectedKernelPackages = 
    if kernelVersion == "latest" then pkgs.linuxPackages_latest
    else if kernelVersion == "6_12" then pkgs.linuxPackages_6_12
    else if kernelVersion == "6_18" then pkgs.linuxPackages_6_18
    else if kernelVersion == "6_19" then pkgs.linuxPackages_6_19
    else pkgs.linuxPackages_latest;

in {
  # Apply selected kernel packages to boot configuration
  boot.kernelPackages = lib.mkDefault selectedKernelPackages;
  
  # GPU-specific configurations
  hardware.nvidia.enable = lib.mkDefault enableNVIDIA;
  nixpkgs.config.rocmSupport = lib.mkDefault enableROCM;
  
  # Set display driver based on GPU type
  services.xserver.videoDrivers = 
    if enableNVIDIA then [ "nvidia" ]
    else if enableROCM then [ "amdgpu" ]
    else [];
}
