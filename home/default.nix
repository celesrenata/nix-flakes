# Main Home Manager Configuration Entry Point
# This file serves as the central hub for all user environment configurations.
# It imports specialized modules and sets basic user information.
#
# Module Organization:
# - desktop/    : Hyprland, Quickshell, theming, and desktop environment
# - programs/   : Development tools, media applications, productivity software
# - shell/      : Shell configurations and command-line tools
# - system/     : System integration, dotfiles, and environment variables

{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, ... }:

{
  # Import all configuration modules
  imports = [
    # Desktop Environment Configuration
    # ./desktop/hyprland.nix          # Moved to platform-specific configs
    ./desktop/hypridle.nix          # Hypridle idle management and power saving
    ./desktop/quickshell.nix        # Quickshell desktop shell
    ./desktop/theming.nix           # Cursors, themes, and visual appearance
    
    # Application and Program Configuration
    ./programs/comfyui.nix          # ComfyUI AI image generation service
    ./programs/development.nix      # Development tools (VSCode, Git, Python, etc.)
    ./programs/media.nix            # Media applications (OBS, players, editors)
    ./programs/productivity.nix     # Productivity tools (browsers, file managers)
    ./programs/terminal.nix         # Terminal emulators and CLI tools
    
    # Shell Environment Configuration
    ./shell/fish.nix                # Fish shell configuration and integration
    ./shell/bash.nix                # Bash shell configuration
    ./shell/starship.nix            # Starship cross-shell prompt
    
    # System Integration Configuration
    ./system/files.nix              # Dotfiles and home.file configurations
    ./system/packages.nix           # Desktop environment and system packages
    ./system/variables.nix          # Environment variables and system settings
    ./system/hyte-touch.nix         # Hyte Touch Display user service
    ./system/hyte-touch.nix         # Hyte Touch Display user service
  ];

  # Basic user configuration
  # These settings define the fundamental user environment
  home.username = "celes";                    # System username
  home.homeDirectory = "/home/celes";         # User home directory path
  home.stateVersion = "25.11";                # Home Manager state version for compatibility

  # Enable Home Manager self-management
  # This allows Home Manager to manage its own installation and updates
  programs.home-manager.enable = true;
}
