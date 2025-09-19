# Professional NixOS Configuration - Multi-Platform Support

A comprehensive, modular NixOS configuration supporting baremetal x86_64 systems and Apple MacBook T2 hardware. Features enterprise-grade architecture, extensive customization, and a modern Wayland desktop environment.

## Supported Platforms

### Baremetal x86_64 (`esnixi`)
- **Target**: Physical x86_64 hardware with NVIDIA GPU support
- **Graphics**: NVIDIA drivers with CUDA acceleration for AI/ML workloads
- **Features**: Gaming (Steam, VR), development environment, virtualization (Docker, QEMU)
- **Optimizations**: Hardware-specific drivers, performance tuning, multi-monitor support

### MacBook T2 (`macland`) 
- **Target**: Apple MacBook with T2 security chip
- **Graphics**: AMD integrated graphics with ROCm support
- **Features**: Touch Bar support, T2-specific drivers, Mac-style keybindings, power management
- **Hardware**: Broadcom WiFi/Bluetooth firmware, audio pipeline, thermal management

### Raspberry Pi 5 (`rpi5`)
- **Status**: Available on separate RPI5 branch for ARM64 architecture
- **Note**: Switch to RPI5 branch for ARM-specific configuration

## Features

### Desktop Environment
- **Hyprland (Wayland)** - Modern tiling window manager
- **Customized End-4's Dots** - Beautiful, functional desktop configuration
- **Mac-style Keybindings** - Familiar shortcuts for Mac users
- **Professional Theming** - Consistent visual design

### Development Tools
- **VSCode with Nix backend** - Fully integrated development environment
- **JetBrains Toolbox (Wayland)** - Complete IDE suite
- **Git with advanced configuration** - Professional version control
- **Python, Node.js, CMake** - Complete development stack
- **Ollama built-in** - Local AI/ML capabilities (T2 supported!)

### Gaming & Media
- **Steam with optimizations** - Gaming platform with performance tweaks
- **ALVR** - VR streaming support
- **Hardware acceleration** - GPU-optimized media playback

### Enterprise Features
- **SOPS-nix secrets management** - Encrypted secrets with age/SSH keys
- **Modular architecture** - Clean, maintainable configuration structure
- **Professional documentation** - Comprehensive inline comments
- **Remote build support** - Distributed compilation capabilities

### Productivity
- **Customized Winapps with M365** - Windows applications via RDP (**Bring your own licenses!**)
- **Suspend/Resume for T2** - Power management that actually works
- **Multi-monitor support** - Professional workspace setup

## Screenshots

### Theming
![Desktop Theme 1](http://www.celestium.life/wp-content/uploads/2024/06/image.png)
![Desktop Theme 2](http://www.celestium.life/wp-content/uploads/2024/06/theme2.png)

### Development Environment
![Development Setup](http://www.celestium.life/wp-content/uploads/2024/07/productivity.png)

### Gaming
![Gaming Configuration](http://www.celestium.life/wp-content/uploads/2024/07/gaming.png)

## Installation

**For detailed step-by-step instructions, see `CONTEXT_INSTALLATION.md`**

### Quick Start - Baremetal x86_64

1. **Boot NixOS installer** and prepare system
2. **Clone configuration**:
   ```bash
   nix-shell -p git
   sudo mkdir -p /mnt/sources && sudo chown 1000:100 /mnt/sources
   cd /mnt/sources && git clone https://github.com/celesrenata/nix-flakes
   cp -r nix-flakes/* /mnt/etc/nixos/
   ```
3. **Install system**:
   ```bash
   sudo nixos-install --root /mnt --flake /mnt/etc/nixos#esnixi
   sudo nixos-enter && sudo passwd celes && sudo poweroff
   ```

### Quick Start - MacBook T2

1. **Complete T2 Linux preparation** ([T2 Linux guide](https://wiki.t2linux.org/distributions/nixos/home/))
2. **Copy T2 firmware** to `/mnt/etc/nixos/macland/firmware/`
3. **Install system**:
   ```bash
   sudo nixos-install --root /mnt --flake /mnt/etc/nixos#macland
   ```

### Post-Installation
- Login through GDM, system will initialize automatically
- Press `Command + Option + /` for keybinding cheatsheet
- Run `~/winapps/runmefirst.sh` for Office 365 setup (optional)

## Winapps Configuration

Winapps allows you to run Windows applications seamlessly integrated into your Linux desktop. This configuration includes a customized setup for Microsoft Office 365 and other Windows applications.

### How It Works
- **RDP Integration**: Uses FreeRDP to connect to a Windows VM or remote Windows machine
- **Seamless Experience**: Windows applications appear as native Linux applications
- **Office 365 Support**: Pre-configured for Microsoft Office suite
- **Custom Icons**: Applications appear in your application menu with proper icons

### Setup Requirements
- **Windows VM or Remote Machine**: You need access to a Windows system
- **RDP Enabled**: Windows machine must have RDP enabled
- **Valid Licenses**: Bring your own Windows and Office 365 licenses
- **Network Access**: Reliable network connection to Windows machine

### Platform Support
- **Baremetal (esnixi)**: Full support - configure your own Windows VM
- **MacBook T2 (macland)**: Full support - built-in Windows VM configuration
- **Raspberry Pi 5**: Limited support due to performance constraints

See installation instructions above for platform-specific setup steps.

## Configuration Structure

This configuration uses a modular architecture for maintainability:

```
nixos/
├── flake.nix                    # Main flake with comprehensive documentation
├── configuration.nix           # Core system configuration
├── secrets.nix                 # SOPS secrets management (currently disabled)
├── hardware-configuration.nix  # Auto-generated hardware detection
├── remote-build.nix            # Distributed build configuration
├── setup-certificate.sh       # Certificate setup script
│
├── esnixi/                     # Baremetal x86_64 configurations
│   ├── boot.nix               # GRUB EFI bootloader
│   ├── graphics.nix           # NVIDIA drivers and CUDA
│   ├── networking.nix         # Advanced network configuration
│   ├── virtualisation.nix     # Docker, QEMU, KVM support
│   ├── games.nix              # Steam and gaming optimizations
│   └── *.nix                  # Additional platform modules
│
├── macland/                    # MacBook T2 configurations
│   ├── boot.nix               # T2-compatible bootloader
│   ├── graphics.nix           # AMD graphics and ROCm
│   ├── sound.nix              # Complex T2 audio system
│   ├── cpu.nix                # Intel CPU and power management
│   ├── firmware/              # T2 firmware files
│   └── *.nix                  # Additional T2 modules
│
├── home/                       # Modular home-manager configuration
│   ├── desktop/               # Hyprland, theming, desktop environment
│   ├── programs/              # Development, media, productivity apps
│   ├── shell/                 # Fish, bash, starship configurations
│   └── system/                # System integration and packages
│
├── overlays/                   # Custom package modifications
├── patches/                    # Source code patches
├── modules/                    # Custom NixOS modules
├── scripts/                    # Windows installation scripts
├── secrets/                    # Encrypted secrets storage
└── user/                       # User-specific configurations
```

## Customization

### Creating Your Own Configuration
1. Fork this repository
2. Create a new branch: `git checkout -b my-config`
3. Modify configurations in the appropriate modules
4. Update `flake.nix` with your system name
5. Test with `nixos-rebuild dry-run --flake .#yoursystem`

### Key Customization Points
- **Username**: Update in `home/default.nix` and system configurations
- **Hardware**: Modify platform-specific files in `esnixi/` or `macland/`
- **Applications**: Add/remove packages in `home/programs/` modules
- **Secrets**: Configure SOPS keys and add secrets as needed

## Secrets Management

This configuration includes enterprise-grade secrets management using SOPS-nix:

- **Encrypted storage**: Secrets encrypted with age/SSH keys
- **Version control safe**: Encrypted files can be committed to git
- **Automatic decryption**: Secrets available at `/run/secrets/` during runtime
- **Key backup**: SSH host keys automatically backed up

See `CONFIGURATION.md` for detailed secrets management instructions.

## Known Limitations

### Current Issues
- **SOPS symlink conflict**: Minor issue with certificate deployment (system fully functional)
- **Winapps setup**: Requires manual configuration for Windows VM connection
  - Baremetal: Full support with proper Windows VM setup
  - T2 MacBooks: Full support with built-in configuration
  - RPi5: Performance limitations prevent reliable operation
- **Tiny-DFR keycode**: Touch Bar function keys need keycode adjustment

### Platform-Specific Notes
- **T2 MacBooks**: Suspend/resume works, but initial setup may take time
- **NVIDIA GPUs**: Requires proprietary drivers (automatically handled)
- **JetBrains IDEs**: Requires restart of AGS or logout for Wayland support

## Support & Documentation

- **Context Files**: Comprehensive documentation in `CONTEXT_*.md` files
  - `CONTEXT_MAIN.md`: Repository overview and architecture
  - `CONTEXT_INSTALLATION.md`: Step-by-step installation guide
  - `CONTEXT_PLATFORMS.md`: Platform-specific configurations
  - `CONTEXT_HOME.md`: Home Manager user environment
  - `CONTEXT_SUMMARY.md`: Overview of all context files
- **Architecture Guide**: See `CONFIGURATION.md` for detailed documentation
- **T2 MacBook Issues**: Refer to [T2 Linux Wiki](https://wiki.t2linux.org/)
- **NixOS Help**: Consult [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- **Home Manager**: See [Home Manager Manual](https://nix-community.github.io/home-manager/)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Follow the existing documentation standards
4. Test your changes thoroughly
5. Submit a pull request with detailed description

## License

This configuration is provided as-is for educational and personal use. Please respect software licenses for included applications and bring your own licenses where required (e.g., Microsoft Office 365).
