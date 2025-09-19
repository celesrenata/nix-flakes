# Installation Guide Context

## Installation Overview

This NixOS configuration supports two primary platforms with different installation procedures:
- **esnixi**: Baremetal x86_64 systems with NVIDIA GPU support
- **macland**: Apple MacBook with T2 security chip

## Prerequisites by Platform

### Baremetal x86_64 (esnixi)
- **Hardware**: x86_64 system with UEFI boot support
- **GPU**: NVIDIA GPU recommended for full feature set
- **Storage**: Minimum 50GB, SSD recommended
- **Network**: Internet connection for package downloads
- **Memory**: Minimum 8GB RAM, 16GB+ recommended

### MacBook T2 (macland)
- **Hardware**: Apple MacBook with T2 security chip
- **Preparation**: T2 Linux installation guide completion required
- **Firmware**: WiFi and Bluetooth firmware files needed
- **Storage**: Minimum 50GB free space
- **Network**: Internet connection (may need USB tethering initially)

## Installation Process

### Phase 1: NixOS Base Installation

#### Step 1: Boot NixOS Installer
**For both platforms:**
1. Download NixOS ISO from [nixos.org](https://nixos.org/download.html)
2. Create bootable USB or use netboot.xyz:
   - Select Linux Network Installs
   - Select NixOS
   - Select NixOS Unstable (or 24.05)
3. Boot from installation media

#### Step 2: Prepare Installation Environment
```bash
# Install git for repository cloning
nix-shell -p git

# Follow standard NixOS installation process
# Partition disks, format filesystems, mount at /mnt
# Generate hardware configuration
sudo nixos-generate-config --root /mnt
```

#### Step 3: Clone Configuration Repository
```bash
# Create sources directory
sudo mkdir -p /mnt/sources
sudo chown 1000:100 /mnt/sources
cd /mnt/sources

# Clone this repository
git clone https://github.com/celesrenata/nix-flakes
cp -r nix-flakes/* /mnt/etc/nixos/

# Optional: Create personal branch for customizations
# cd /mnt/etc/nixos
# git checkout -b my-config
```

### Phase 2: Platform-Specific Installation

#### For Baremetal x86_64 (esnixi)
```bash
# Install the system with esnixi configuration
sudo nixos-install --root /mnt --flake /mnt/etc/nixos#esnixi

# Set user password
sudo nixos-enter
sudo passwd celes
sudo poweroff
```

#### For MacBook T2 (macland)
**Prerequisites:**
1. Complete [T2 Linux Installation guide](https://wiki.t2linux.org/distributions/nixos/home/)
2. Ensure WiFi and Bluetooth firmware is available

**Installation:**
```bash
# Copy T2 firmware to configuration
cp firmware/* /mnt/etc/nixos/macland/firmware/

# Install with macland configuration
sudo nixos-install --root /mnt --flake /mnt/etc/nixos#macland

# Set user password
sudo nixos-enter
sudo passwd celes
sudo poweroff
```

### Phase 3: First Boot and Initialization

#### Step 1: Initial System Boot
1. Remove installation media
2. Boot the installed system
3. Login through GDM (GNOME Display Manager)
4. System will run initialization scripts and may reboot automatically

#### Step 2: Desktop Environment Setup
1. Wait for system to fully initialize
2. Press `Command + Option + /` to open keybinding cheatsheet
3. Familiarize yourself with Mac-style keybindings
4. Test basic desktop functionality

### Phase 4: Winapps Configuration (Optional)

#### For Both Platforms
**Requirements:**
- Windows VM or remote Windows machine
- RDP enabled on Windows system
- Valid Windows and Office 365 licenses
- Reliable network connection

**Setup Process:**
1. Wait for system to fully initialize
2. Navigate to Winapps directory: `cd ~/winapps`
3. Run setup script: `./runmefirst.sh`
4. Follow prompts to configure Windows VM connection
5. Install Office 365 or other Windows applications
6. Press `Command + Control + R` to refresh XDG applications
7. Launch Windows applications from application menu

#### Platform-Specific Winapps Notes

**Baremetal (esnixi):**
- Full support with proper Windows VM setup
- Configure your own Windows VM or remote machine
- Excellent performance with dedicated hardware

**MacBook T2 (macland):**
- Full support with built-in Windows VM configuration
- May take time for http://127.0.0.1:8006 to complete setup
- Launch 'windows' from spotlight to login to Office 365

## Post-Installation Configuration

### System Updates
```bash
# Update flake inputs
sudo nix flake update

# Rebuild system with updates
sudo nixos-rebuild switch --flake /etc/nixos#<platform>

# Update home manager
home-manager switch --flake /etc/nixos
```

### Customization
1. **Create personal branch**: `git checkout -b my-config`
2. **Modify configurations**: Edit files in appropriate modules
3. **Test changes**: `nixos-rebuild dry-run --flake .#<platform>`
4. **Apply changes**: `nixos-rebuild switch --flake .#<platform>`

### Troubleshooting Common Issues

#### SOPS Symlink Conflict
- **Issue**: Certificate deployment fails
- **Impact**: System fully functional, only affects certificates
- **Workaround**: Manual certificate management if needed

#### JetBrains Wayland Support
- **Issue**: IDEs may not support Wayland initially
- **Solution**: Restart AGS or logout/login after installation

#### T2 MacBook Specific
- **WiFi issues**: Ensure firmware files are properly copied
- **Touch Bar**: May need keycode adjustment for function keys
- **Suspend/resume**: Works but initial setup may take time

## Verification Steps

### System Health Check
1. **Boot successfully**: System boots to desktop
2. **Network connectivity**: Internet access working
3. **Graphics**: Proper display resolution and acceleration
4. **Audio**: Sound output functional
5. **Input devices**: Keyboard and mouse/trackpad working

### Application Testing
1. **Terminal**: Open and test terminal emulator
2. **Browser**: Launch web browser and test internet
3. **File manager**: Navigate filesystem
4. **Development tools**: Test VSCode or preferred editor

### Platform-Specific Verification

**esnixi:**
- **NVIDIA drivers**: Check `nvidia-smi` output
- **Gaming**: Test Steam if gaming is required
- **Virtualization**: Verify Docker/QEMU if needed

**macland:**
- **Touch Bar**: Test function key behavior
- **WiFi/Bluetooth**: Verify wireless connectivity
- **Battery**: Check power management
- **Thermal**: Monitor temperature and fan behavior

## Maintenance

### Regular Updates
- **Weekly**: `nix flake update && nixos-rebuild switch`
- **Monthly**: Review and clean up old generations
- **As needed**: Update specific packages or configurations

### Backup Strategy
- **Configuration**: Git repository with personal branch
- **SSH keys**: Backup SSH host keys for SOPS
- **User data**: Regular home directory backups
- **System state**: Consider system snapshots for rollback
