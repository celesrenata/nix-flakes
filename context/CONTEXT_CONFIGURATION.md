# Core System Configuration Context (configuration.nix)

## Purpose
Main NixOS system configuration file that defines core system settings shared across all platforms.

## Key Configuration Areas

### System Fundamentals
- **Unfree packages**: Enabled for proprietary software support
- **Host platform**: Optimized for x86-64-v3 architecture
- **Flakes**: Experimental features enabled for modern Nix usage
- **Local bin path**: Enables ~/.local/bin in PATH

### Boot Configuration
- **Plymouth**: Boot splash screen enabled
- **Grub EFI**: Boot loader configuration (platform-specific)
- **Kernel packages**: Flexible kernel selection

### Localization & Time
- **Timezone**: America/Los_Angeles (configurable)
- **Locale**: en_US.UTF-8 with full locale settings
- **Keyboard**: US layout with international support

### Security & Authentication
- **PAM limits**: Unlimited stack size for development
- **Certificate management**: SOPS-based (currently disabled)
- **User authentication**: Standard Unix authentication

### Hardware Support
- **Udev rules**: Hardware device management
- **Input devices**: Support for various input methods
- **Hardware detection**: Automatic via hardware-configuration.nix

### Services & Networking
- **NetworkManager**: Modern network management
- **SSH**: Secure shell access configuration
- **Printing**: CUPS printing system
- **Audio**: PipeWire audio system

### Desktop Environment
- **Display manager**: GDM (GNOME Display Manager)
- **Wayland**: Modern display protocol support
- **X11**: Legacy X11 support when needed

### Development Environment
- **Git**: Version control system
- **Development tools**: Compilers, interpreters, build systems
- **Container support**: Docker/Podman integration

### Package Management
- **System packages**: Core system utilities
- **Overlays**: Custom package modifications
- **Garbage collection**: Automatic cleanup configuration

## Platform Integration
This file is imported by platform-specific configurations (esnixi/, macland/) which add:
- Hardware-specific drivers
- Platform-specific services
- Custom boot configurations
- Specialized networking setups

## Imports
- `hardware-configuration.nix`: Auto-generated hardware detection
- Platform-specific modules via flake system configurations
