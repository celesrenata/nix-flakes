# Remote Build Configuration
# This module configures remote build capabilities for NixOS.
# It can be used to offload builds to more powerful machines or build farms.
#
# Common use cases:
# - Building on a powerful server while developing on a laptop
# - Cross-compilation for different architectures
# - Distributed builds across multiple machines
#
# Configuration examples:
# - SSH-based remote builders
# - Build farm integration
# - Cross-platform build support

{ config, lib, pkgs, ... }:

{
  # Remote build configuration placeholder
  # This file was created as a minimal placeholder to prevent build errors.
  # 
  # To configure remote builds, uncomment and modify the following examples:
  
  # Example: SSH-based remote builder
  # nix.buildMachines = [
  #   {
  #     hostName = "builder.example.com";
  #     system = "x86_64-linux";
  #     maxJobs = 4;
  #     speedFactor = 2;
  #     supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
  #     mandatoryFeatures = [ ];
  #   }
  # ];
  
  # Example: Enable distributed builds
  # nix.distributedBuilds = true;
  
  # Example: Use remote builders as substituters
  # nix.extraOptions = ''
  #   builders-use-substitutes = true
  # '';
}
