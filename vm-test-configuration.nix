# NixOS VM Test Configuration for Experimental Flake
# =============================================================================
# This script creates a QEMU VM using your experimental flake configuration
# Safe way to test before deploying to actual hardware!
#
# Requirements:
#   - nixos-test-runner or qemu-system-x86_64 installed
#   - Sufficient disk space (~20GB recommended)
# =============================================================================

{ config, pkgs, lib, ... }:

let
  # VM Configuration (adjust based on your esnixi specs)
  vmCpus = 4;                # Number of CPU cores for VM
  vmMemory = "8192";         # Memory in MB (8GB recommended)
  vmDiskSize = "60G";        # Disk size in GB
  
in

{
  imports = [
    ./configuration.nix       # Your main NixOS config from flake
    ../esnixi/boot.nix        # Boot configuration
    ../esnixi/graphics.nix    # Graphics configuration
    ../esnixi/networking.nix  # Network configuration
    ../esnixi/virtualisation.nix # Virtualization settings
  ];

  # VM-Specific Settings
  boot.loader.grub.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  
  # Console for easier interaction
  consoleLogLevel = 0;
  
  # Network configuration (bridge for internet access)
  networking.useDHCP = true;
  
  # User setup for VM testing
  users.users.testuser = {
    isNormalUser = true;
    description = "Test User";
    extraGroups = [ "wheel" ];
    initialPassword = "test123";
  };

  # Enable SSH in VM (for remote access if needed)
  services.openssh.enable = true;
  
  # Allow root login via password for simplicity in testing
  security.sudo.wheelNeedsPassword = false;
  
  # Additional packages for testing
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    net-tools
    nmap
    tmux
  ];

}
