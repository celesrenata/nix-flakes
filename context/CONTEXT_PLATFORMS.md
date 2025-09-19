# Platform-Specific Configurations Context

## esnixi/ - Baremetal x86_64 Configuration

### Purpose
Configuration for physical x86_64 hardware with NVIDIA GPU support, optimized for gaming, development, and AI/ML workloads.

### Files Overview

#### boot.nix
- **Bootloader**: GRUB EFI configuration
- **Kernel**: Latest kernel with performance optimizations
- **Boot parameters**: Hardware-specific boot options
- **Plymouth**: Boot splash configuration

#### graphics.nix
- **NVIDIA drivers**: Proprietary GPU drivers with CUDA
- **OpenGL**: Hardware-accelerated graphics
- **Wayland support**: Modern display protocol
- **Multi-monitor**: Advanced display configuration

#### networking.nix
- **NetworkManager**: Advanced network management
- **Firewall**: Security configuration
- **VPN support**: Network privacy tools
- **Bridge networking**: Virtualization networking

#### virtualisation.nix
- **Docker**: Container platform
- **QEMU/KVM**: Virtual machine support
- **Libvirt**: Virtualization management
- **GPU passthrough**: Hardware virtualization

#### games.nix
- **Steam**: Gaming platform with optimizations
- **Proton**: Windows game compatibility
- **Game-specific tweaks**: Performance optimizations
- **VR support**: ALVR and VR gaming

#### authentication.nix
- **User management**: Account configuration
- **SSH keys**: Secure authentication
- **Sudo configuration**: Administrative access

#### monitoring.nix
- **System monitoring**: Performance tracking
- **Log management**: System logging
- **Health checks**: System status monitoring

#### thunderbolt.nix
- **Thunderbolt support**: High-speed connectivity
- **Device management**: Thunderbolt device handling

#### open-webui.nix
- **Web UI services**: Browser-based interfaces
- **Service management**: Web service configuration

## macland/ - MacBook T2 Configuration

### Purpose
Configuration for Apple MacBook with T2 security chip, including Touch Bar support and Mac-specific hardware.

### Files Overview

#### boot.nix
- **T2-compatible bootloader**: Special boot configuration
- **Kernel parameters**: T2-specific boot options
- **Firmware loading**: Apple firmware integration

#### graphics.nix
- **AMD graphics**: Integrated graphics support
- **ROCm support**: AMD GPU compute
- **Display management**: Mac display handling

#### networking.nix
- **WiFi firmware**: Broadcom WiFi support
- **Bluetooth**: Apple Bluetooth integration
- **Network optimization**: Mac-specific networking

#### sound.nix (extensive configuration)
- **Audio drivers**: T2 audio system support
- **Speaker configuration**: MacBook speaker setup
- **Microphone**: Built-in microphone support
- **Audio routing**: Complex audio pipeline

#### cpu.nix
- **Intel CPU**: Mac CPU optimization
- **Power management**: Battery and thermal management
- **Performance scaling**: CPU frequency management

#### virtualisation.nix
- **Limited virtualization**: T2-compatible virtualization
- **Container support**: Docker with T2 considerations
- **Performance constraints**: Hardware limitations

#### games.nix
- **Limited gaming**: T2 gaming constraints
- **Compatibility**: Mac gaming considerations

#### thunderbolt.nix
- **T2 Thunderbolt**: Apple Thunderbolt implementation
- **USB-C support**: Modern connectivity

#### firmware/
- **Broadcom firmware**: WiFi and Bluetooth firmware files
- **T2 drivers**: Apple T2 security chip drivers
- **Hardware support**: Mac-specific firmware

## Platform Selection
- **esnixi**: Choose for powerful desktop/workstation with NVIDIA GPU
- **macland**: Choose for MacBook with T2 chip
- **Hardware detection**: Automatic via hardware-configuration.nix

## Common Features
Both platforms support:
- **Hyprland desktop**: Modern Wayland environment
- **Development tools**: Full development stack
- **Home Manager**: User environment management
- **SOPS secrets**: Encrypted configuration management
- **Modular architecture**: Clean, maintainable code

## Installation Differences
- **esnixi**: Standard NixOS installation process
- **macland**: Requires T2 Linux preparation and firmware
- **Post-install**: Platform-specific setup scripts and services
