# Professional NixOS Configuration - Baremetal & MacBook T2 Support

A comprehensive, modular NixOS configuration supporting both baremetal x86_64 systems and Apple MacBook T2 hardware. Features enterprise-grade secrets management, professional documentation, and a modern desktop environment.

## Supported Platforms

### Baremetal x86_64 (`esnixi`)
- **Target**: Physical x86_64 hardware with NVIDIA GPU support
- **Graphics**: NVIDIA GPU with CUDA acceleration for AI/ML workloads
- **Features**: Gaming, development environment, virtualization support
- **Optimizations**: Hardware-specific drivers and performance tuning

### MacBook T2 (`macland`) 
- **Target**: Apple MacBook with T2 security chip
- **Graphics**: AMD ROCm support for integrated graphics
- **Features**: Touch Bar support, T2-specific drivers, Mac-style keybindings
- **Hardware**: WiFi, Bluetooth, audio, and thermal management

### Raspberry Pi 5 (`rpi5`)
- **Branch**: Please switch to RPI5 branch for ARM64 support
- **Status**: Separate branch maintained for ARM architecture

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

### Baremetal x86_64 Installation

#### Prerequisites
- x86_64 hardware with UEFI boot support
- NVIDIA GPU (recommended for full feature set)
- Internet connection for package downloads

#### Installation Steps
1. **Boot NixOS installer**
   - Download NixOS ISO from [nixos.org](https://nixos.org/download.html)
   - Boot from USB/DVD or use netboot.xyz:
     1. Select Linux Network Installs
     2. Select NixOS
     3. Select NixOS Unstable (or 24.05)

2. **Prepare the system**
   ```bash
   # Install git for cloning the configuration
   nix-shell -p git
   
   # Follow standard NixOS installation until configuration step
   # See: https://nixos.org/manual/nixos/unstable/
   sudo nixos-generate-config --root /mnt
   ```

3. **Install the configuration**
   ```bash
   # Create sources directory
   sudo mkdir -p /mnt/sources
   sudo chown 1000:100 /mnt/sources
   cd /mnt/sources
   
   # Clone this repository
   git clone https://github.com/celesrenata/nix-flakes
   cp -r nix-flakes/* /mnt/etc/nixos/
   
   # Consider creating your own branch for customizations
   # git checkout -b my-config
   
   # Install the system
   sudo nixos-install --root /mnt --flake /mnt/etc/nixos#esnixi
   
   # Set user password
   sudo nixos-enter
   sudo passwd celes
   sudo poweroff
   ```

4. **Post-installation**
   - Boot the system
   - Login through GDM (GNOME Display Manager)
   - System will run initialization scripts and reboot automatically
   - Press `Command + Option + /` to open the keybinding cheatsheet

5. **Setup Winapps (Optional)**
   - Wait for system to fully initialize
   - Navigate to Winapps directory: `cd ~/winapps`
   - Run the setup script: `./runmefirst.sh`
   - Follow prompts to configure Windows VM connection
   - Install Office 365 or other Windows applications as needed
   - Press `Command + Control + R` to refresh XDG applications
   - Launch Windows applications from the application menu

### MacBook T2 Installation

1. **Follow T2 Linux preparation**
   - Complete the [T2 Linux Installation guide](https://wiki.t2linux.org/distributions/nixos/home/) first
   - Ensure WiFi and Bluetooth firmware is available

2. **Install git and clone configuration**
   ```bash
   nix-shell -p git
   # Follow standard NixOS installation steps
   sudo nixos-generate-config --root /mnt
   sudo mkdir -p /mnt/sources
   sudo chown 1000:100 /mnt/sources
   cd /mnt/sources
   git clone https://github.com/celesrenata/nix-flakes
   cp -r nix-flakes/* /mnt/etc/nixos/
   ```

3. **Copy T2 firmware**
   ```bash
   # Copy firmware from T2 Linux preparation to:
   cp firmware/* /mnt/etc/nixos/macland/firmware/
   ```

4. **Install MacBook configuration**
   ```bash
   sudo nixos-install --root /mnt --flake /mnt/etc/nixos#macland
   sudo nixos-enter
   sudo passwd celes
   sudo poweroff
   ```

5. **Post-installation**
   - Login through GDM
   - System will initialize and reboot
   - Wait for http://127.0.0.1:8006 to complete setup (may take time)
   - Run `~/winapps/runmefirst.sh` to setup Office 365
   - Press `Command + Control + R` to refresh XDG applications
   - Launch 'windows' from spotlight to login to Office 365

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
├── secrets.nix                 # SOPS secrets management
├── CONFIGURATION.md            # Detailed architecture documentation
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
└── secrets/                    # Encrypted secrets storage
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
