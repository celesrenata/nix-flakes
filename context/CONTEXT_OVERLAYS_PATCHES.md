# Overlays and Patches Context

## overlays/ - Custom Package Modifications

### Purpose
Custom package definitions and modifications that extend or fix packages not available or working correctly in nixpkgs.

### Package Categories

#### Development Tools
- **android-studio.nix**: Android development IDE
- **cmake-js.nix**: CMake JavaScript bindings
- **debugpy.nix**: Python debugging tools
- **jetbrains-toolbox.nix**: JetBrains IDE manager with Wayland support
- **rbtools.nix**: Review Board development tools

#### Desktop Applications
- **cider.nix**: Apple Music client
- **fuzzel-emoji.nix**: Emoji picker for Wayland
- **gnome-pie.nix**: Circular application launcher
- **kando.nix**: Pie menu application
- **keyboard-visualizer.nix**: RGB keyboard visualization
- **nextcloud-client/**: Cloud storage client

#### AI/ML and Graphics
- **background-removal.nix**: AI background removal tool
- **comfyui.nix**: AI image generation interface
- **materialyoucolor.nix**: Material You color theming
- **onnxruntime.nix**: ONNX machine learning runtime
- **tensorrt.nix**: NVIDIA TensorRT inference

#### System Utilities
- **end-4-dots.nix**: End-4's desktop configuration
- **freerdp.nix**: Remote desktop protocol client
- **keyd.nix**: Key remapping daemon
- **toshy.nix**: Mac-style keybindings for Linux
- **tinydfr.nix**: MacBook Touch Bar support

#### Gaming and Media
- **sunshine.nix**: Game streaming server
- **wofi-calc.nix**: Calculator for Wayland
- **xivlauncher.nix**: Final Fantasy XIV launcher

#### Hardware Support
- **t2fanrd.nix**: MacBook T2 fan control
- **nvidia-open-*.nix**: NVIDIA open-source driver variants
- **nvidia-6.16-patch.nix**: Kernel 6.16 compatibility

#### Cloud and DevOps
- **helmfile.nix**: Kubernetes Helm file manager
- **kubevirt.nix**: Kubernetes virtualization
- **latex.nix**: LaTeX document preparation

#### Utilities
- **nix-static.nix**: Static Nix binary
- **nmap.nix**: Network mapping tool
- **unstable.nix**: Access to unstable packages

## patches/ - Source Code Modifications

### Purpose
Patch files that modify source code of various applications to fix bugs, add features, or customize behavior.

### Patch Categories

#### Desktop Environment Patches
- **ags.*.patch**: AGS (Aylur's GTK Shell) modifications
- **hypr.*.patch**: Hyprland window manager customizations
- **system.js.patch**: System integration fixes

#### Application Customizations
- **applycolor.sh.patch**: Color scheme application
- **cheatsheet.*.patch**: Keybinding cheatsheet modifications
- **foot.ini.patch**: Foot terminal configuration
- **fish.config.fish.patch**: Fish shell customizations

#### Hardware Support
- **keyd.*.patch**: Key remapping daemon fixes
- **nvidia-*.patch**: NVIDIA driver patches for kernel compatibility
- **rk3328-*.patch**: ARM device tree patches

#### User Interface
- **data_keyboardlayouts.js.patch**: Keyboard layout data
- **sequences.txt.patch**: Input sequence definitions
- **user_options.js.patch**: User interface options

## Integration

### Overlay System
- **Automatic loading**: All overlays loaded via flake.nix
- **Package precedence**: Custom packages override nixpkgs
- **Platform-specific**: Some overlays only apply to specific platforms

### Patch Application
- **Build-time**: Patches applied during package compilation
- **Source modification**: Direct source code changes
- **Compatibility**: Ensures patches work with current package versions

### Maintenance
- **Version tracking**: Patches updated with upstream changes
- **Testing**: Patches tested across platform configurations
- **Documentation**: Each patch includes purpose and scope

## Usage
- **Automatic**: Overlays and patches applied automatically during build
- **Custom packages**: Available as regular packages in configuration
- **Debugging**: Individual overlays can be disabled for troubleshooting
