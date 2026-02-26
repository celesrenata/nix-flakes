# Example NixOS configuration for EXO
# Add this to your NixOS configuration.nix or as a separate module

{ config, lib, pkgs, ... }:

{
  # Import the EXO flake (adjust the path to your flake)
  imports = [
    # If using flakes, add to your flake inputs and reference here
    # inputs.exo.nixosModules.default
  ];

  # Enable EXO service
  services.exo = {
    enable = true;
    accelerator = "cpu"; # Options: "cpu", "cuda", "rocm", "intel", "mlx"
    port = 52415;
    openFirewall = true; # Set to false if you manage firewall manually
  };

  # Optional: Add EXO package to system packages for manual use
  environment.systemPackages = with pkgs; [
    # If using overlay from flake:
    # exo-cpu
    # Or build manually:
    # (callPackage ./path/to/exo/flake.nix {}).packages.${system}.exo-cpu
  ];

  # Optional: Configure networking for cluster communication
  networking.firewall = {
    allowedTCPPorts = [ 52415 ]; # EXO default port
    # Add additional ports if needed for cluster communication
  };

  # Optional: Add user to exo group for manual management
  users.users.myuser = {
    extraGroups = [ "exo" ];
  };
}