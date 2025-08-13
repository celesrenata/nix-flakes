# NixOS Configuration Documentation

This repository contains a comprehensive NixOS configuration supporting both ESXi virtual machines and Apple MacBook T2 hardware. The configuration is modular, well-documented, and includes enterprise-grade secrets management.

## Table of Contents

- [Overview](#overview)
- [Supported Platforms](#supported-platforms)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration Management](#configuration-management)
- [Secrets Management](#secrets-management)
- [Development](#development)
- [Maintenance](#maintenance)

## Overview

This NixOS configuration provides:

- **Modular Architecture**: Clean separation of concerns with logical module organization
- **Multi-Platform Support**: Optimized configurations for ESXi VMs and MacBook T2 hardware
- **Desktop Environment**: Hyprland with End-4's customized configuration
- **Development Tools**: Comprehensive development environment with VSCode, Git, Python, AWS tools
- **Gaming Support**: Steam, ALVR, and gaming optimizations
- **Secrets Management**: SOPS-nix for encrypted secrets and certificate management
- **Enterprise Features**: Remote builds, monitoring, virtualization support

## Supported Platforms

### ESXi Virtual Machine (`esnixi`)
- **Target**: VMware ESXi virtual machines with GPU passthrough
- **Graphics**: NVIDIA GPU support with CUDA acceleration
- **Features**: Gaming, AI/ML workloads, development environment
- **Optimizations**: VM-specific kernel parameters and drivers

### MacBook T2 (`macland`)
- **Target**: Apple MacBook with T2 security chip
- **Graphics**: AMD ROCm support for integrated graphics
- **Features**: Touch Bar support, T2-specific drivers, Mac-style keybindings
- **Hardware**: WiFi, Bluetooth, audio, and thermal management

## Architecture

### Directory Structure

```
nixos/
├── flake.nix                    # Main flake configuration with comprehensive documentation
├── flake.lock                  # Locked dependency versions
├── configuration.nix           # Core system configuration
├── hardware-configuration.nix  # Hardware detection results
├── secrets.nix                 # SOPS secrets management configuration
├── remote-build.nix            # Remote build configuration
├── home-modular.nix            # Modular home-manager entry point
├── .sops.yaml                  # SOPS encryption configuration
├── .gitignore                  # Git ignore rules for sensitive files
│
├── esnixi/                     # ESXi-specific configurations
│   ├── boot.nix               # Boot loader and kernel settings
│   ├── games.nix              # Gaming optimizations
│   ├── graphics.nix           # NVIDIA GPU configuration
│   ├── monitoring.nix         # System monitoring
│   ├── networking.nix         # Network configuration
│   ├── thunderbolt.nix        # Thunderbolt support
│   └── virtualisation.nix     # VM and container support
│
├── macland/                    # MacBook T2-specific configurations
│   ├── boot.nix               # T2-compatible boot configuration
│   ├── cpu.nix                # CPU optimizations
│   ├── games.nix              # Gaming setup for macOS compatibility
│   ├── graphics.nix           # Apple graphics drivers
│   ├── networking.nix         # WiFi/Bluetooth configuration
│   ├── sound.nix              # Audio system configuration
│   ├── thunderbolt.nix        # Thunderbolt support
│   └── virtualisation.nix     # Virtualization for Apple hardware
│
├── home/                       # Modular home-manager configuration
│   ├── default.nix            # Main entry point with comprehensive imports
│   ├── desktop/               # Desktop environment configuration
│   │   ├── hyprland.nix       # Hyprland window manager and keybindings
│   │   ├── quickshell.nix     # Quickshell desktop shell
│   │   └── theming.nix        # Cursors, themes, and visual appearance
│   ├── programs/              # Application configurations
│   │   ├── development.nix    # Development tools (VSCode, Git, Python)
│   │   ├── media.nix          # Media applications (OBS, players, editors)
│   │   ├── productivity.nix   # Productivity tools (browsers, file managers)
│   │   └── terminal.nix       # Terminal emulators and CLI tools
│   ├── shell/                 # Shell configurations
│   │   ├── bash.nix           # Bash shell configuration
│   │   ├── fish.nix           # Fish shell with integrations
│   │   └── starship.nix       # Cross-shell prompt configuration
│   └── system/                # System integration
│       ├── files.nix          # Dotfiles and home.file configurations
│       ├── packages.nix       # Desktop environment packages
│       └── variables.nix      # Environment variables
│
├── secrets/                    # Encrypted secrets storage
│   └── secrets.yaml           # SOPS-encrypted secrets file
│
├── overlays/                   # Custom package overlays
│   ├── *.nix                  # Various package modifications and additions
│
└── scripts/                    # Utility scripts
    └── setup-certificate.sh   # Certificate management helper
```

### Key Design Principles

1. **Modularity**: Each component is in its own file with clear responsibilities
2. **Documentation**: Comprehensive inline comments and documentation
3. **Platform Separation**: Platform-specific configurations are isolated
4. **Security**: Secrets are encrypted and properly managed
5. **Maintainability**: Clear structure makes updates and modifications easy

## Installation

### Prerequisites

1. **NixOS Installation**: Follow the [official NixOS installation guide](https://nixos.org/manual/nixos/unstable/)
2. **Git**: Required for flake management
3. **Age Key**: For secrets management (generated automatically)

### Initial Setup

1. **Clone the repository**:
   ```bash
   sudo mkdir -p /mnt/sources
   sudo chown 1000:100 /mnt/sources
   cd /mnt/sources
   git clone https://github.com/celesrenata/nix-flakes
   cp -r nix-flakes/* /mnt/etc/nixos/
   ```

2. **Generate hardware configuration**:
   ```bash
   sudo nixos-generate-config --root /mnt
   ```

3. **Install the system**:
   ```bash
   # For ESXi VM:
   sudo nixos-install --root /mnt --flake /mnt/etc/nixos#esnixi
   
   # For MacBook T2:
   sudo nixos-install --root /mnt --flake /mnt/etc/nixos#macland
   ```

4. **Set user password**:
   ```bash
   sudo nixos-enter
   sudo passwd celes
   sudo poweroff
   ```

### Post-Installation

1. **Boot the system** and login through GDM
2. **System will run initialization scripts** and reboot automatically
3. **Configure secrets** (see Secrets Management section)

## Configuration Management

### Making Changes

1. **Edit configuration files** as needed
2. **Test changes** with dry-run:
   ```bash
   sudo nixos-rebuild dry-run --flake .#esnixi
   ```
3. **Apply changes**:
   ```bash
   sudo nixos-rebuild switch --flake .#esnixi
   ```

### Adding New Modules

1. **Create the module file** in the appropriate directory
2. **Add comprehensive documentation** with inline comments
3. **Import the module** in the relevant `default.nix` file
4. **Test the configuration** before committing

### Platform-Specific Modifications

- **ESXi-specific**: Modify files in `esnixi/` directory
- **MacBook-specific**: Modify files in `macland/` directory
- **Shared changes**: Modify files in `home/` or root directory

## Secrets Management

This configuration uses SOPS-nix for enterprise-grade secrets management.

### Initial Setup

1. **Age key is generated automatically** on first build
2. **Key location**: `/home/celes/.config/sops/age/keys.txt`
3. **Public key**: Check the `.sops.yaml` file for your public key

### Managing Secrets

1. **Edit encrypted secrets**:
   ```bash
   nix-shell -p sops --run "sops secrets/secrets.yaml"
   ```

2. **View decrypted secrets** (for debugging):
   ```bash
   nix-shell -p sops --run "sops -d secrets/secrets.yaml"
   ```

3. **Add new certificate**:
   ```bash
   ./setup-certificate.sh
   ```

### Adding New Secrets

1. **Edit the secrets file** to add new entries
2. **Update `secrets.nix`** to define the new secret
3. **Reference the secret** in your configuration as `/run/secrets/secret_name`

## Development

### Development Shells

The configuration provides development environments:

```bash
# Default development shell (Helm/Kubernetes)
nix develop

# Custom development environments can be added to flake.nix
```

### Custom Overlays

Package modifications are managed through overlays in the `overlays/` directory:

- **Create new overlay**: Add `overlays/my-package.nix`
- **Import overlay**: Add to the overlays list in `flake.nix`
- **Document changes**: Include comments explaining modifications

### Testing Changes

1. **Syntax check**: `nix flake check`
2. **Dry run**: `nixos-rebuild dry-run --flake .#esnixi`
3. **Build test**: `nix build .#nixosConfigurations.esnixi.config.system.build.toplevel`

## Maintenance

### Regular Updates

1. **Update flake inputs**:
   ```bash
   nix flake update
   ```

2. **Review changes**:
   ```bash
   git diff flake.lock
   ```

3. **Test and apply**:
   ```bash
   sudo nixos-rebuild switch --flake .#esnixi
   ```

### Backup Important Files

- **Age private key**: `/home/celes/.config/sops/age/keys.txt`
- **Hardware configuration**: `hardware-configuration.nix`
- **Custom certificates**: Ensure they're properly encrypted in SOPS

### Troubleshooting

1. **Build failures**: Check `--show-trace` for detailed error information
2. **Module conflicts**: Review import statements and module organization
3. **Secrets issues**: Verify age key permissions and SOPS configuration
4. **Platform issues**: Check platform-specific module configurations

## Contributing

When contributing to this configuration:

1. **Follow the modular structure**
2. **Add comprehensive documentation**
3. **Test on both platforms when possible**
4. **Use proper commit messages**
5. **Avoid emojis in code comments** (UTF-8 compatibility)

## Support

For platform-specific issues:

- **ESXi**: Check VMware documentation and GPU passthrough guides
- **MacBook T2**: Refer to [T2 Linux Wiki](https://wiki.t2linux.org/)
- **NixOS**: Consult [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- **Home Manager**: See [Home Manager Manual](https://nix-community.github.io/home-manager/)
