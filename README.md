# NixOS Flake Configuration

A modular NixOS configuration with support for multiple platforms, featuring Hyprland desktop environment, AI/ML tools, and extensive hardware support.

## Platforms

### esnixi (Baremetal x86_64)
Primary workstation configuration with NVIDIA GPU support, gaming capabilities, and AI/ML acceleration.

### macland (MacBook T2)
Apple MacBook configuration with T2 chip support, AMD graphics, Touch Bar integration, and power management.

## Features

- **Hyprland Wayland Compositor** - Modern tiling window manager with custom End-4 dots configuration
- **AI/ML Stack** - ComfyUI, OneTrainer, Ollama, vLLM, Exo distributed inference
- **Development Environment** - VSCode, JetBrains Toolbox, Git, Python, Node.js
- **Gaming** - Steam, ALVR VR streaming, hardware acceleration
- **Virtualization** - Docker, QEMU/KVM support
- **Custom Hardware** - Hyte Y70 Touch-Infinite display support
- **Secrets Management** - SOPS-nix for encrypted configuration

## Structure

```
.
├── flake.nix              # Main flake configuration with inputs/outputs
├── configuration.nix      # Core system configuration
├── flake.lock            # Locked dependency versions
│
├── esnixi/               # Baremetal x86_64 platform
│   ├── boot.nix         # GRUB bootloader configuration
│   ├── graphics.nix     # NVIDIA 580 drivers with CUDA
│   ├── networking.nix   # Network configuration
│   ├── virtualisation.nix # Docker and QEMU
│   ├── games.nix        # Steam and gaming setup
│   ├── vllm.nix         # vLLM inference server
│   ├── lvra.nix         # LVRA AI assistant
│   ├── exo.nix          # Exo distributed inference
│   ├── hyte-touch.nix   # Hyte display integration
│   └── hyprland.nix     # Platform-specific Hyprland config
│
├── macland/             # MacBook T2 platform
│   ├── boot.nix        # T2-compatible bootloader
│   ├── graphics.nix    # AMD graphics with ROCm
│   ├── sound.nix       # T2 audio pipeline
│   ├── cpu.nix         # Intel CPU and power management
│   ├── firmware/       # T2 firmware files (Broadcom WiFi/BT)
│   └── hyprland.nix    # Platform-specific Hyprland config
│
├── home/               # Home Manager user configuration
│   ├── default.nix    # Main home-manager entry point
│   ├── desktop/       # Desktop environment
│   │   ├── hyprland.nix    # Hyprland configuration
│   │   ├── quickshell.nix  # Quickshell desktop shell
│   │   ├── hypridle.nix    # Idle management
│   │   └── theming.nix     # Themes and cursors
│   ├── programs/      # Application configurations
│   │   ├── development.nix  # Dev tools (VSCode, Git)
│   │   ├── comfyui.nix     # ComfyUI AI image generation
│   │   ├── lvra.nix        # LVRA configuration
│   │   ├── media.nix       # Media apps (OBS, players)
│   │   ├── productivity.nix # Browsers, file managers
│   │   └── terminal.nix    # Terminal emulators
│   ├── shell/         # Shell configurations
│   │   ├── fish.nix
│   │   ├── bash.nix
│   │   └── starship.nix
│   └── system/        # System integration
│       ├── packages.nix    # System packages
│       ├── files.nix       # Dotfiles management
│       ├── variables.nix   # Environment variables
│       └── hyte-touch.nix  # User service
│
├── overlays/          # Package overlays and modifications
│   ├── comfyui.nix
│   ├── jetbrains-toolbox.nix
│   ├── nvidia-*.nix
│   ├── ollama.nix
│   ├── toshy.nix
│   └── ... (40+ overlays)
│
├── modules/           # Custom NixOS modules
│   ├── background-removal.nix
│   ├── graphics-nvidia.nix
│   └── vr/
│
├── patches/           # Source code patches
│   ├── hypr.*.patch
│   ├── ags.*.patch
│   ├── nvidia-*.patch
│   └── keyd.*.patch
│
├── scripts/           # Helper scripts
│   └── install-*.ps1  # Windows application installers
│
├── secrets/           # SOPS encrypted secrets
│   └── secrets.yaml
│
└── docs/             # Documentation
    └── comfyui-dynamic-dependencies.md
```

## Installation

### Prerequisites

- NixOS installer ISO
- For T2 MacBooks: Follow [T2 Linux guide](https://wiki.t2linux.org/distributions/nixos/home/)
- For T2: Copy firmware files to `macland/firmware/`

### Basic Installation

1. Boot NixOS installer and partition disks
2. Mount root to `/mnt`
3. Clone repository:
```bash
nix-shell -p git
sudo mkdir -p /mnt/sources && sudo chown 1000:100 /mnt/sources
cd /mnt/sources
git clone <repository-url> nixos
cd nixos
```

4. Install system:
```bash
# For baremetal x86_64
sudo nixos-install --root /mnt --flake .#esnixi

# For MacBook T2
sudo nixos-install --root /mnt --flake .#macland
```

5. Set user password:
```bash
sudo nixos-enter
passwd celes
exit
```

6. Reboot and login through GDM

## Key Technologies

### Desktop Environment
- **Hyprland** - Wayland compositor with tiling
- **Quickshell** - Desktop shell and widgets
- **End-4 Dots** - Custom desktop configuration
- **GDM** - Display manager

### AI/ML Tools
- **ComfyUI** - Node-based AI image generation
- **OneTrainer** - Diffusion model training
- **Ollama** - Local LLM inference
- **vLLM** - High-performance LLM serving
- **Exo** - Distributed inference across devices
- **LVRA** - AI assistant integration

### Graphics
- **NVIDIA 580 drivers** (esnixi) - Latest drivers with CUDA support
- **AMD ROCm** (macland) - AMD GPU compute
- **Hardware acceleration** - VA-API, NVENC/NVDEC

### Development
- **VSCode** - With Nix backend and extensions
- **JetBrains Toolbox** - Full IDE suite
- **Git** - Version control with advanced config
- **Python, Node.js, CMake** - Development runtimes

### Virtualization
- **Docker** - Container runtime
- **QEMU/KVM** - Virtual machines
- **Libvirt** - VM management

## Flake Inputs

- `nixpkgs` - NixOS 25.11 stable
- `nixpkgs-unstable` - Latest packages
- `home-manager` - User environment management
- `dots-hyprland` - End-4's Hyprland configuration
- `nix-comfyui` - ComfyUI flake
- `onetrainer-flake` - OneTrainer integration
- `exo` - Distributed inference
- `hyte-touch-infinite-flakes` - Hyte display support
- `tiny-dfr` - MacBook Touch Bar
- `nixos-hardware` - Hardware configurations
- `sops-nix` - Secrets management
- `ags` - Desktop shell (gorsbart fork)
- `cline-cli` - AI coding assistant

## Configuration Management

### Rebuilding System
```bash
# Rebuild and switch
sudo nixos-rebuild switch --flake .#esnixi

# Test without switching
sudo nixos-rebuild test --flake .#esnixi

# Build only
sudo nixos-rebuild build --flake .#esnixi
```

### Updating Flake
```bash
# Update all inputs
nix flake update

# Update specific input
nix flake lock --update-input nixpkgs
```

### Home Manager
```bash
# Rebuild home environment
home-manager switch --flake .#celes@esnixi
```

## Customization

### Adding Packages
- System packages: Edit `configuration.nix` or platform-specific files
- User packages: Edit `home/system/packages.nix`
- Overlays: Add to `overlays/` directory

### Platform-Specific Configuration
- Baremetal: Modify files in `esnixi/`
- MacBook: Modify files in `macland/`

### Desktop Customization
- Hyprland: Edit `home/desktop/hyprland.nix`
- Quickshell: Edit `home/desktop/quickshell.nix`
- Theming: Edit `home/desktop/theming.nix`

## Hardware Support

### esnixi
- NVIDIA RTX GPUs (580 drivers)
- CUDA acceleration
- Multi-monitor support
- Hyte Y70 Touch-Infinite display
- Gaming peripherals

### macland
- Apple T2 security chip
- Touch Bar (tiny-dfr)
- Broadcom WiFi/Bluetooth
- AMD integrated graphics
- Power management and suspend/resume

## Secrets Management

Uses SOPS-nix for encrypted secrets:
- Secrets stored in `secrets/secrets.yaml`
- Encrypted with age/SSH keys
- Configuration in `.sops.yaml`
- Decrypted at runtime to `/run/secrets/`

## Remote Build Support

Configuration includes remote build capabilities:
- Distributed compilation
- Build offloading to remote machines
- See `remote-build.nix` for configuration

## License

MIT License - See LICENSE file for details

Copyright (c) 2024 Celes Renata

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [T2 Linux Wiki](https://wiki.t2linux.org/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
