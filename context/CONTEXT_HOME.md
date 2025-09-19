# Home Manager Configuration Context (home/)

## Purpose
Modular user environment configuration using Home Manager for dotfiles, applications, and user-specific settings.

## Directory Structure

### home/default.nix
Central entry point that imports all home manager modules and sets basic user configuration:
- **Username**: celes
- **Home directory**: /home/celes
- **State version**: 24.11 for compatibility
- **Self-management**: Home Manager manages its own installation

### home/desktop/
Desktop environment and window manager configurations:

#### hyprland.nix
- **Hyprland configuration**: Wayland tiling window manager
- **Keybindings**: Mac-style shortcuts and custom bindings
- **Window rules**: Application-specific window behavior
- **Workspace management**: Multi-monitor and workspace setup
- **Animations**: Smooth transitions and effects

#### hypridle.nix
- **Idle management**: Screen timeout and power saving
- **Lock screen**: Automatic screen locking
- **Suspend behavior**: System suspend configuration

#### quickshell.nix
- **Desktop shell**: Modern shell replacement (placeholder)
- **Widget configuration**: Desktop widgets and panels

#### theming.nix
- **Cursor themes**: Mouse cursor appearance
- **GTK themes**: Application theming
- **Icon themes**: System and application icons
- **Color schemes**: Consistent color palette

### home/programs/
Application-specific configurations:

#### development.nix
- **VSCode**: Editor configuration with extensions
- **Git**: Version control with advanced settings
- **Python**: Development environment setup
- **Node.js**: JavaScript development tools
- **CMake**: Build system configuration

#### media.nix
- **OBS Studio**: Streaming and recording
- **Media players**: Video and audio playback
- **Image editors**: Graphics editing tools
- **Screen capture**: Screenshot and recording tools

#### productivity.nix
- **Web browsers**: Firefox, Chrome configurations
- **File managers**: Nautilus, terminal file managers
- **Office applications**: Document editing and viewing
- **Communication**: Chat and email clients

#### terminal.nix
- **Terminal emulators**: Foot, Alacritty configurations
- **CLI tools**: Command-line utilities and enhancements
- **Terminal multiplexers**: tmux, screen configurations

#### comfyui.nix
- **ComfyUI service**: AI image generation service
- **Model management**: AI model configuration
- **Service integration**: Systemd service setup

### home/shell/
Shell environment configurations:

#### fish.nix
- **Fish shell**: Modern shell with intelligent features
- **Aliases**: Command shortcuts and abbreviations
- **Functions**: Custom shell functions

#### bash.nix
- **Bash configuration**: Traditional shell setup
- **Compatibility**: Fallback shell configuration

#### starship.nix
- **Cross-shell prompt**: Modern, fast prompt
- **Git integration**: Repository status display
- **Language detection**: Development environment indicators

### home/system/
System integration and environment:

#### files.nix
- **Dotfiles**: Configuration file management
- **Symlinks**: Home directory file linking
- **Templates**: Configuration templates

#### packages.nix
- **User packages**: Applications and utilities
- **Desktop environment**: GUI applications
- **Development tools**: Programming utilities

#### variables.nix
- **Environment variables**: System-wide variables
- **PATH configuration**: Binary path management
- **Application settings**: Environment-based configuration

## Integration
- **Platform awareness**: Adapts to esnixi vs macland configurations
- **Service management**: User-level systemd services
- **XDG compliance**: Follows XDG Base Directory specification
- **State management**: Maintains configuration state across rebuilds
