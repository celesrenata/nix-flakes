# Context Files Summary

This directory contains comprehensive context documentation for the NixOS configuration repository. These files provide detailed information about each component to assist with understanding, installation, and maintenance.

## Context Files Overview

### CONTEXT_MAIN.md
**Purpose**: Repository overview and architecture
**Contains**: 
- Supported platforms (esnixi, macland, rpi5)
- Core features and capabilities
- Directory structure explanation
- Key features by category
- Current limitations and known issues

### CONTEXT_FLAKE.md
**Purpose**: Flake configuration documentation
**Contains**:
- Input dependencies and their purposes
- System configuration definitions
- Overlay system explanation
- Home Manager integration
- Build commands and usage

### CONTEXT_CONFIGURATION.md
**Purpose**: Core system configuration documentation
**Contains**:
- System fundamentals (boot, locale, security)
- Hardware support configuration
- Service and networking setup
- Desktop environment integration
- Development environment setup

### CONTEXT_HOME.md
**Purpose**: Home Manager configuration documentation
**Contains**:
- Modular home configuration structure
- Desktop environment settings (Hyprland, theming)
- Application configurations (development, media, productivity)
- Shell environment setup (fish, bash, starship)
- System integration and dotfiles management

### CONTEXT_PLATFORMS.md
**Purpose**: Platform-specific configuration documentation
**Contains**:
- esnixi (baremetal x86_64) configuration details
- macland (MacBook T2) configuration details
- Hardware-specific drivers and optimizations
- Platform selection guidance
- Installation differences between platforms

### CONTEXT_OVERLAYS_PATCHES.md
**Purpose**: Custom packages and modifications documentation
**Contains**:
- Overlay system for custom packages
- Patch system for source modifications
- Package categories (development, desktop, AI/ML, gaming)
- Integration and maintenance procedures

### CONTEXT_SECRETS.md
**Purpose**: Security and secrets management documentation
**Contains**:
- SOPS-nix configuration (currently disabled)
- Encrypted secrets storage system
- Security architecture and threat model
- Current issues and workarounds
- Alternative security approaches

### CONTEXT_MODULES_SCRIPTS.md
**Purpose**: Custom modules and automation scripts documentation
**Contains**:
- Custom NixOS modules (background-removal, graphics-nvidia)
- Installation scripts for Windows applications
- Remote build configuration
- User-specific configurations
- Integration points and maintenance

### CONTEXT_INSTALLATION.md
**Purpose**: Comprehensive installation guide
**Contains**:
- Platform-specific prerequisites
- Step-by-step installation process
- Post-installation configuration
- Winapps setup procedures
- Troubleshooting common issues
- Verification and maintenance steps

## How to Use These Context Files

### For Installation
1. Start with **CONTEXT_MAIN.md** for overview
2. Review **CONTEXT_PLATFORMS.md** to choose your platform
3. Follow **CONTEXT_INSTALLATION.md** for step-by-step installation
4. Reference other files for specific component understanding

### For Customization
1. **CONTEXT_HOME.md** for user environment changes
2. **CONTEXT_OVERLAYS_PATCHES.md** for custom packages
3. **CONTEXT_MODULES_SCRIPTS.md** for system extensions
4. **CONTEXT_FLAKE.md** for dependency management

### For Troubleshooting
1. **CONTEXT_INSTALLATION.md** for common installation issues
2. **CONTEXT_SECRETS.md** for security-related problems
3. **CONTEXT_PLATFORMS.md** for hardware-specific issues
4. **CONTEXT_CONFIGURATION.md** for system configuration problems

### For Maintenance
1. **CONTEXT_FLAKE.md** for updating dependencies
2. **CONTEXT_OVERLAYS_PATCHES.md** for package maintenance
3. **CONTEXT_MODULES_SCRIPTS.md** for module updates
4. **CONTEXT_INSTALLATION.md** for system maintenance procedures

## Integration with AI Assistant

These context files are designed to be read by AI assistants to provide:
- **Comprehensive understanding** of the repository structure
- **Accurate installation guidance** based on platform and requirements
- **Informed troubleshooting** for common issues
- **Customization assistance** for specific needs
- **Maintenance guidance** for ongoing system management

## Maintenance of Context Files

### When to Update
- **Major configuration changes**: Update relevant context files
- **New features added**: Document in appropriate context files
- **Installation process changes**: Update CONTEXT_INSTALLATION.md
- **Known issues resolved**: Update limitation sections

### Consistency Requirements
- **Cross-references**: Ensure context files reference each other accurately
- **Version alignment**: Keep context files aligned with actual configuration
- **Completeness**: Ensure all major components are documented
- **Clarity**: Maintain clear, actionable documentation

This context system provides a comprehensive knowledge base for understanding, installing, and maintaining this NixOS configuration across all supported platforms.
