# Flake Configuration Context (flake.nix)

## Purpose
Central flake definition that manages all external dependencies, system configurations, and build outputs for the NixOS configuration.

## Key Sections

### Inputs (External Dependencies)
- **nixpkgs**: Multiple channels (stable 25.05, old 24.11, unstable)
- **home-manager**: User environment management (release-25.05)
- **anyrun**: Application launcher
- **niri**: Experimental Wayland compositor
- **dots-hyprland**: End-4's Hyprland configuration (custom fork)
- **nix-gl-host/nixgl**: OpenGL support for non-NixOS
- **nixos-hardware**: Hardware-specific configurations
- **tiny-dfr**: MacBook Touch Bar support
- **protontweaks**: Steam Proton enhancements
- **dream2nix**: Language-specific package management
- **nix-vscode-extensions**: VSCode extensions
- **ags**: Desktop shell and widgets (gorsbart fork)
- **sops-nix**: Encrypted secrets management

### System Configurations
- **esnixi**: Baremetal x86_64 system with NVIDIA support
- **macland**: MacBook T2 system with Apple hardware support

### Overlays
Defines custom package modifications and additions:
- Custom packages from overlays/ directory
- Platform-specific package overrides
- Unstable package access

### Home Manager Integration
- Configures user environment for each system
- Imports home/ directory modules
- Passes through all inputs to home configuration

## Build Outputs
- `nixosConfigurations.esnixi`: Baremetal system configuration
- `nixosConfigurations.macland`: MacBook T2 system configuration
- Home Manager configurations for each system

## Usage
- `nixos-rebuild switch --flake .#esnixi`: Build baremetal system
- `nixos-rebuild switch --flake .#macland`: Build MacBook system
- `nix flake update`: Update all input dependencies
- `nix flake show`: Display available configurations
