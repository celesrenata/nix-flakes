# Modules and Scripts Context

## modules/ - Custom NixOS Modules

### Purpose
Custom NixOS modules that extend system functionality beyond what's available in standard nixpkgs.

### Available Modules

#### background-removal.nix
- **Purpose**: AI-powered background removal service
- **Functionality**: Provides background removal capabilities for images/video
- **Integration**: Systemd service with API interface
- **Dependencies**: AI/ML libraries and models
- **Usage**: Image editing and video processing workflows

#### graphics-nvidia.nix
- **Purpose**: Advanced NVIDIA graphics configuration
- **Functionality**: 
  - NVIDIA driver management with multiple versions
  - CUDA support and configuration
  - OpenGL and Vulkan setup
  - Multi-GPU support
  - Power management
- **Features**:
  - Automatic driver selection
  - PRIME support for hybrid graphics
  - Performance optimization
  - Wayland compatibility
- **Platform**: Primarily for esnixi (baremetal x86_64)

### Module Architecture
- **Declarative configuration**: NixOS-style option definitions
- **Service integration**: Systemd service management
- **Dependency management**: Automatic package and service dependencies
- **Platform awareness**: Conditional loading based on hardware/platform

## scripts/ - Installation and Setup Scripts

### Purpose
PowerShell and batch scripts for Windows application installation, primarily for Winapps integration.

### Script Categories

#### Office 365 Installation
- **install-office365.ps1**: Microsoft Office 365 installation script
- **Purpose**: Automated Office suite installation in Windows VM
- **Features**: Silent installation, license activation, configuration
- **Integration**: Used by Winapps for seamless Office integration

#### System Utilities
- **install-nevergreen.ps1**: Nevergreen application installer
- **install-winkey.ps1**: Windows key management utility
- **Purpose**: System utility installation and configuration

#### Batch Scripts
- **install.bat**: Basic installation batch script
- **install2.bat**: Alternative installation method
- **Purpose**: Simple installation automation

### Winapps Integration
These scripts are designed to work with the Winapps system:
1. **Windows VM setup**: Scripts run inside Windows VM
2. **Application installation**: Automated software installation
3. **Configuration**: Application setup and configuration
4. **Integration**: Seamless Linux desktop integration

## remote-build.nix - Distributed Building

### Purpose
Configuration for distributed NixOS builds across multiple machines for faster compilation.

### Features
- **Build delegation**: Offload builds to more powerful machines
- **SSH integration**: Secure remote build execution
- **Load balancing**: Distribute builds across available builders
- **Architecture support**: Cross-architecture building

### Configuration Elements
- **Builder machines**: List of available build machines
- **SSH keys**: Authentication for remote builders
- **Capabilities**: What each builder can compile
- **Preferences**: Builder selection preferences

### Benefits
- **Faster builds**: Parallel compilation across machines
- **Resource optimization**: Use available compute resources
- **Cross-compilation**: Build for different architectures
- **Development efficiency**: Reduced local build times

## user/ - User-Specific Configurations

### Purpose
User-specific configuration files and templates that don't fit in home manager.

### Structure
```
user/
└── default/
    ├── workflows/              # Empty directory for user workflows
    ├── comfy.settings.json     # ComfyUI settings (minimal)
    └── comfy.templates.json    # ComfyUI templates (empty)
```

### ComfyUI Configuration
- **Settings**: Basic ComfyUI configuration
- **Templates**: Workflow templates for AI image generation
- **User data**: Personal ComfyUI customizations

## Integration Points

### System Integration
- **Modules**: Loaded automatically via flake configuration
- **Scripts**: Called during post-installation setup
- **Remote builds**: Configured per-system basis
- **User configs**: Integrated with home manager

### Platform Awareness
- **Conditional loading**: Modules load based on platform (esnixi/macland)
- **Hardware detection**: Graphics modules adapt to available hardware
- **Service management**: Platform-specific service configuration

### Maintenance
- **Version compatibility**: Modules updated with NixOS releases
- **Testing**: Scripts tested across platform configurations
- **Documentation**: Inline documentation for complex modules
- **Error handling**: Robust error handling and recovery
