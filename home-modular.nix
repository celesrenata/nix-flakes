# Modular Home Manager Configuration Entry Point
# This file replaces the monolithic home.nix with a modular structure
# for better maintainability and organization.
#
# The configuration is split into logical modules:
# - desktop/    : Desktop environment and window manager settings
# - programs/   : Application configurations and settings
# - shell/      : Shell configurations (bash, fish, starship)
# - system/     : System integration (files, packages, variables)

{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, ... }:

{
  # Import all modular components
  # The main configuration is defined in home/default.nix
  imports = [
    ./home/default.nix
  ];

  # Note: Arguments (inputs, pkgs, etc.) are automatically passed down
  # to all imported modules through the module system.
  # No need to manually override _module.args here.
}
