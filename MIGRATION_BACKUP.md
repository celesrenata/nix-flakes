# Migration Backup Log

## Migration from ~/sources/nixos to ~/sources/nix-flakes

**Date:** $(date)
**System:** macland (MacBook T2)

## Key Configurations to Preserve:

### 1. Sound Configuration
- Working T2 DSP audio setup from stable config
- pkgs-old audio plugins configuration
- Microphone boost service
- Complex PipeWire filter chains

### 2. Keyboard Configuration
- keyd configuration for Mac-style remapping
- Custom keyboard mappings

### 3. Hardware Configuration
- Current hardware-configuration.nix
- T2-specific boot and graphics settings

### 4. Package Overlays
- Custom overlays that may be missing in new config
- T2-specific overlays (t2fanrd, etc.)

### 5. System Services
- Custom systemd services
- Audio-related services

## Migration Strategy:
1. Backup current working configurations
2. Copy hardware-configuration.nix
3. Migrate macland-specific configurations
4. Update flake.nix with missing inputs/overlays
5. Test build before switching

## Files to Migrate:
- macland/sound.nix (complete working version)
- macland/cpu.nix
- macland/graphics.nix
- hardware-configuration.nix
- Any custom overlays
- toshy-modern.nix (if still needed)
