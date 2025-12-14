# NixOS Raspberry Pi 5 Configuration

Personal NixOS flake configuration for Raspberry Pi 5 with Hyprland desktop environment.

## Features

- **Raspberry Pi 5 optimizations**: 16K page size, VC4 display driver, Bluetooth support
- **Hyprland desktop**: Wayland compositor with end-4 dots configuration
- **Home Manager**: Declarative user environment management
- **Custom overlays**: JetBrains Toolbox, Material You Color, Argon ONE daemon, and more
- **Hardware support**: Logitech wireless devices, Argon ONE case fan control
- **Development tools**: Kubernetes (k3s, helm), JetBrains Toolbox, Amazon Q CLI
- **Media**: Kodi, Jellyfin, Moonlight game streaming
- **Distributed builds**: Remote build support for faster compilation

## Prerequisites

- Raspberry Pi 5
- NixOS installer (netboot.xyz or official ISO)
- Internet connection

## Installation

### 1. Boot NixOS Installer

Using netboot.xyz:
1. Select **Linux Network Installs** → **NixOS** → **Unstable** (or 24.05)
2. Once booted, install git: `nix-shell -p git`

### 2. Partition and Mount Disks

Follow the [NixOS Installation Guide](https://nixos.wiki/wiki/NixOS_Installation_Guide) for disk partitioning and mounting to `/mnt`.

### 3. Install Configuration

```bash
# Generate hardware configuration
sudo nixos-generate-config --root /mnt

# Clone this repository
sudo mkdir -p /mnt/sources
sudo chown 1000:100 /mnt/sources
cd /mnt/sources
git clone https://github.com/celesrenata/nix-flakes
cp -r nix-flakes/* /mnt/etc/nixos/

# Install NixOS with flake
sudo nixos-install --root /mnt --flake /mnt/etc/nixos#nixberry

# Set user password
sudo nixos-enter
passwd celes
exit

# Shutdown and remove installer
sudo poweroff
```

### 4. First Boot

1. Boot the system and login as `celes`
2. Select **Hyprland** at the display manager (Enlightenment is available as fallback)
3. Initial setup runs automatically - system will reboot after first stage
4. After reboot, the desktop will configure itself with the default wallpaper
5. View keybindings: `Super + Alt + /`

## Project Structure

```
.
├── flake.nix              # Main flake configuration
├── configuration.nix      # System-wide configuration
├── home.nix              # Home Manager user configuration
├── hardware-configuration.nix  # Hardware-specific settings (generated)
├── remote-build.nix      # Distributed build configuration
├── nixberry/             # Raspberry Pi 5 specific modules
│   ├── boot.nix         # Boot configuration
│   ├── configtxt.nix    # config.txt settings
│   ├── cpu.nix          # CPU optimizations
│   ├── graphics.nix     # VC4 graphics driver
│   ├── networking.nix   # Network configuration
│   ├── virtualisation.nix  # Docker/virtualization
│   └── wireless.nix     # WiFi/Bluetooth
├── overlays/            # Custom package overlays
├── patches/             # Configuration patches for end-4 dots
├── scripts/             # Setup and utility scripts
└── home/                # Home Manager modules
    └── desktop/
        └── hyprland.nix
```

## Customization

To adapt this configuration for your use:

1. **Fork this repository**
2. **Update username**: Change `celes` to your username in:
   - `configuration.nix` (users.users section)
   - `home.nix` (home.username and home.homeDirectory)
   - `flake.nix` (home-manager.users section)
3. **Adjust hardware**: Modify `hardware-configuration.nix` after generation
4. **Remote builds**: Edit `remote-build.nix` to configure your build machines (or remove if not needed)
5. **Timezone/locale**: Update in `configuration.nix`

## Key Keybindings

- `Super + Alt + /` - Show keybinding cheatsheet
- `Super + Ctrl + R` - Reload Hyprland and AGS configuration
- `Super + Q` - Close window
- `Super + Return` - Open terminal

## Notes

- The configuration uses the `nixos-raspberrypi` flake for Pi 5 support
- First boot takes longer due to Home Manager service building Python packages on ARM
- The `end-4-dots` configuration is applied via overlays and patches
- Distributed builds can significantly speed up rebuilds if you have additional build machines

## Flake Outputs

- `nixberry` - Raspberry Pi 5 configuration (aarch64-linux)

## License

See LICENSE file for details.
