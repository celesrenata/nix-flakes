# NixOS Configuration Repository - Main Context

## Repository Overview
This is a comprehensive NixOS configuration supporting multiple platforms with enterprise-grade features, modular architecture, and professional desktop environment.

## Supported Platforms
- **esnixi**: Baremetal x86_64 systems with NVIDIA GPU support
- **macland**: Apple MacBook with T2 security chip
- **rpi5**: Raspberry Pi 5 (separate branch)

## Core Architecture

### Main Configuration Files
- `flake.nix`: Central flake definition with all inputs and system configurations
- `configuration.nix`: Core NixOS system configuration shared across platforms
- `hardware-configuration.nix`: Auto-generated hardware detection (do not modify)
- `secrets.nix`: SOPS-nix encrypted secrets management (currently disabled)
- `remote-build.nix`: Distributed build configuration

### Directory Structure
```
nixos/
├── flake.nix                    # Main flake with comprehensive documentation
├── configuration.nix           # Core system configuration
├── secrets.nix                 # SOPS secrets management
├── hardware-configuration.nix  # Auto-generated hardware config
├── remote-build.nix            # Remote build configuration
├── setup-certificate.sh       # Certificate setup script
│
├── esnixi/                     # Baremetal x86_64 configurations
├── macland/                    # MacBook T2 configurations
│
├── home/                       # Modular home-manager configuration
│   ├── desktop/               # Desktop environment settings
│   ├── programs/              # Application configurations
│   ├── shell/                 # Shell configurations
│   └── system/                # System integration
│
├── overlays/                   # Custom package modifications
├── patches/                    # Source code patches
├── modules/                    # Custom NixOS modules
├── scripts/                    # Installation and setup scripts
├── secrets/                    # Encrypted secrets storage
└── user/                       # User-specific configurations
```

## Key Features

### Desktop Environment
- **Hyprland (Wayland)**: Modern tiling window manager
- **End-4's Dots**: Customized desktop configuration
- **Mac-style Keybindings**: Familiar shortcuts for Mac users
- **Professional Theming**: Consistent visual design

### Development Environment
- **VSCode with Nix backend**: Fully integrated development
- **JetBrains Toolbox (Wayland)**: Complete IDE suite
- **Git with advanced configuration**: Professional version control
- **Python, Node.js, CMake**: Complete development stack
- **Ollama built-in**: Local AI/ML capabilities

### Enterprise Features
- **SOPS-nix secrets management**: Encrypted secrets with age/SSH keys
- **Modular architecture**: Clean, maintainable configuration
- **Remote build support**: Distributed compilation
- **Professional documentation**: Comprehensive inline comments

### Gaming & Media
- **Steam with optimizations**: Gaming platform with performance tweaks
- **ALVR**: VR streaming support
- **Hardware acceleration**: GPU-optimized media playback

### Productivity
- **Customized Winapps with M365**: Windows applications via RDP
- **Suspend/Resume for T2**: Power management for MacBooks
- **Multi-monitor support**: Professional workspace setup

## Installation Process Overview
1. Boot NixOS installer
2. Prepare system with standard NixOS installation
3. Clone this repository to `/mnt/etc/nixos/`
4. Install with `nixos-install --flake .#<platform>`
5. Post-installation setup and configuration

## Platform-Specific Notes
- **esnixi**: Requires NVIDIA GPU, supports gaming and AI/ML workloads
- **macland**: Requires T2 firmware, includes Touch Bar and Mac hardware support
- **rpi5**: ARM64 support on separate branch

## Current Limitations
- SOPS symlink conflict (system fully functional without)
- Winapps requires manual Windows VM configuration
- JetBrains IDEs need AGS restart for Wayland support
