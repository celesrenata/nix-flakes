# NixOS configuration snippet to add EXO service with MLX fixes
# Add this to your NixOS configuration or save as a separate .nix file and import it

{ config, pkgs, ... }:

let
  # Import the EXO flake from this directory
  exoFlake = builtins.getFlake "path:/home/celes/sources/celesrenata/exo";
  exoPackage = exoFlake.packages.${pkgs.system}.exo-cpu;
in
{
  # Import the EXO NixOS module
  imports = [
    exoFlake.nixosModules.default
  ];

  # Enable and configure EXO service
  services.exo = {
    enable = true;
    package = exoPackage;
    accelerator = "cpu";  # Force CPU inference on Linux
    port = 52415;
    openFirewall = true;  # Optional: open firewall for dashboard access
  };

  # Add the EXO package to system packages (optional)
  environment.systemPackages = [ exoPackage ];

  # Override the systemd service to ensure proper environment variables
  systemd.services.exo = {
    environment = {
      MLX_DISABLE = "1";
      EXO_INFERENCE_ENGINE = "cpu";
      DASHBOARD_DIR = "${exoPackage}/share/exo/dashboard";
      PYTHONPATH = "${exoPackage}/lib/python3.13/site-packages";
    };
    
    # Ensure service restarts if it fails due to MLX issues
    serviceConfig = {
      Restart = "always";
      RestartSec = "10";
    };
  };
}