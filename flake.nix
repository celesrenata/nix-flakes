{
  description = "Personal NixOS Configuration - ESXi VM and MacBook T2 Support";

  # Input sources for the flake
  # This section defines all external dependencies and their versions
  inputs = {
    # Core NixOS packages - using stable, old, and unstable channels
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";              # Main stable channel
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-24.11";          # Previous stable for compatibility
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";  # Latest packages

    # Home Manager for user environment management
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";  # Use same nixpkgs version

    # Application launchers and desktop utilities
    anyrun.url = "github:Kirottu/anyrun";                          # Application launcher
    # anyrun.inputs.nixpkgs.follows = "nixpkgs";                   # Disabled due to compatibility issues

    # AI and machine learning tools
    nix-comfyui.url = "github:haras-unicorn/nix-comfyui";         # ComfyUI for AI image generation

    # Window managers and desktop environments
    niri.url = "github:sodiboo/niri-flake";                       # Niri wayland compositor (experimental)
    dots-hyprland.url = "github:celesrenata/end-4-flakes";        # End-4's Hyprland configuration
    dots-hyprland.inputs.nixpkgs.follows = "nixpkgs";
    dots-hyprland-source.url = "github:celesrenata/dots-hyprland/quickshell-locked";
    dots-hyprland-source.flake = false;                           # Source files only, not a flake

    # Graphics and OpenGL support
    nix-gl-host.url = "github:numtide/nix-gl-host";               # OpenGL support for non-NixOS
    nixgl.url = "github:nix-community/nixGL";                     # OpenGL wrapper

    # Hardware support
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";    # Hardware-specific configurations
    tiny-dfr.url = "github:sharpenedblade/tiny-dfr";              # MacBook Touch Bar support

    # Gaming and Steam enhancements
    protontweaks.url = "github:rain-cafe/protontweaks/main";       # Steam Proton tweaks

    # Development tools and environments
    dream2nix.url = "github:nix-community/dream2nix";             # Language-specific package management
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";  # VSCode extensions

    # Desktop shell and widgets (currently using gorsbart fork)
    # ags.url = "github:Aylur/ags/main";                          # Original AGS (disabled)
    ags.url = "github:gorsbart/ags";                              # Fork with additional features

    # Secrets management with SOPS (Secrets OPerationS)
    sops-nix.url = "github:Mic92/sops-nix";                       # Encrypted secrets management
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Keyboard remapping (currently disabled in favor of keyd)
    # toshy.url = "github:celesrenata/toshy/cline";               # Mac-style keybindings for Linux
    # toshy.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Flake outputs - defines the actual configurations and development environments
  outputs = inputs@{ nixpkgs, nixpkgs-old, nixpkgs-unstable, anyrun, nix-comfyui, home-manager, dream2nix, niri, nixgl, nix-gl-host, protontweaks, nix-vscode-extensions, nixos-hardware, tiny-dfr, dots-hyprland, dots-hyprland-source, sops-nix, ... }:
  let
    # System architecture - currently only supporting x86_64 Linux
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    
    # Package sets for different use cases
    # Legacy packages for compatibility with older software
    pkgs-old = import inputs.nixpkgs-old {
      inherit system;
      config = {
        allowUnfree = true;    # Allow proprietary software
        allowBroken = true;    # Allow packages marked as broken
      };
    };
    
    # Development shell packages with latest versions
    pkgs-devshell = import inputs.nixpkgs-unstable {
      inherit system;
      config = {
        cudaSupport = true;    # Enable CUDA support for AI/ML workloads
        allowUnfree = true;
        allowBroken = true;
      };
    };

  in {
    # Development environments for various projects
    devShells.x86_64-linux.default = pkgs-devshell.mkShell {
      name = "helmfile devShell";
      nativeBuildInputs = with pkgs-devshell; [
        bashInteractive      # Interactive bash shell
      ];
      buildInputs = with pkgs-devshell; [
        kubernetes-helm-wrapped    # Kubernetes Helm package manager
        helmfile-wrapped          # Declarative Helm chart management
      ];
    };
    
    # Alternative development shell for Toshy (currently disabled)
    # devShells.x86_64 = pkgs-devshell.mkShell {
    #   name = "toshy devShell";
    #   nativeBuildInputs = with pkgs-devshell; [
    #     gobject-intorspection    # GObject introspection for Python bindings
    #     wrapGAppsHook           # GTK application wrapper
    #   ];
    #   buildInputs = with pkgs-devshell; [
    #     gtk3                    # GTK3 development libraries
    #     (python3.withPackages (p: with p; [
    #       pygobject3            # Python GObject bindings
    #     ]))
    #   ];
    # };
    # NixOS system configurations
    nixosConfigurations = {
      # ESXi virtual machine configuration
      # Optimized for VMware ESXi with GPU passthrough support
      esnixi =
      let
      # Main package set with comprehensive overlay support
      pkgs = import inputs.nixpkgs rec {
        inherit system;
        config = {
          # Hardware acceleration and proprietary software support
          cudaSupport = true;                    # NVIDIA CUDA support for AI/ML
          allowUnfree = true;                    # Enable proprietary packages
          android_sdk.accept_license = true;     # Accept Android SDK license
          allowBroken = true;                    # Allow packages marked as broken
          
          # Specific unfree packages whitelist for security
          allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
            "vscode" "discord" "nvidia-x11" "cudatoolkit" "steam" 
            "steam-original" "steam-run" "cuda_cccl"
          ];
          
          # Legacy packages with known security issues (use with caution)
          permittedInsecurePackages = [
            "python-2.7.18.7"    # Required for some legacy tools
            "openssl-1.1.1w"      # Required for some applications
          ];
        };
        
        # Package overlays for custom and modified packages
        overlays = [
          nixgl.overlay                                    # OpenGL support
          # inputs.niri.overlays.niri                     # Niri compositor (disabled)
          inputs.nix-comfyui.overlays.default             # ComfyUI AI tools
          # toshy.overlays.default                        # Toshy keybindings (disabled)
          dots-hyprland.overlays.default                  # Hyprland desktop environment
          
          # Custom overlays for modified or additional packages
          # (import ./overlays/cider.nix)                 # Cider music player (disabled)
          (import ./overlays/tensorrt.nix)                # NVIDIA TensorRT
          (import ./overlays/keyboard-visualizer.nix)     # Audio visualizer
          (import ./overlays/debugpy.nix)                 # Python debugger
          (import ./overlays/freerdp.nix)                 # Remote desktop client
          (import ./overlays/materialyoucolor.nix)        # Material You color theming
          (import ./overlays/end-4-dots.nix)              # End-4 desktop configuration
          (import ./overlays/fuzzel-emoji.nix)            # Emoji picker for Fuzzel
          (import ./overlays/nix-static.nix)              # Static Nix builds
          (import ./overlays/kubevirt.nix)                # Kubernetes virtualization
          (import ./overlays/jetbrains-toolbox.nix)       # JetBrains IDE manager
          (import ./overlays/latex.nix)                   # LaTeX document system
          # (import ./overlays/nmap.nix)                  # Network mapper (disabled)
          (import ./overlays/wofi-calc.nix)               # Calculator for Wofi
          # (import ./overlays/xivlauncher.nix)           # Final Fantasy XIV launcher (disabled)
          # (import ./overlays/toshy.nix)                 # Toshy overlay (disabled)
          (import ./overlays/helmfile.nix)                # Kubernetes Helm management
          (import ./overlays/v4l2loopback.nix)            # Video loopback device
          (import ./overlays/nvidia-open-full.nix)        # NVIDIA open-source drivers
          # (import ./overlays/nvidia-open-debug.nix)     # Debug version (disabled)
          # (import ./overlays/background-removal.nix)    # AI background removal (disabled)
          protontweaks.overlay                            # Steam Proton enhancements
        ];
      };
      
      # Unstable packages for latest software versions
      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config = {
          cudaSupport = true;
          allowUnfree = true;
          allowBroken = true;
        };
      };
      in 
      nixpkgs.lib.nixosSystem {
        # Special arguments passed to all modules
        specialArgs = {
          # inherit niri;                               # Niri compositor (disabled)
          inherit pkgs;                                 # Main package set
          inherit pkgs-unstable;                        # Unstable packages
        };
        
        # Additional system packages available globally
        system.packages = [ 
          anyrun.packages.${system}.anyrun              # Application launcher
          nix-gl-host.defaultPackage.x86_64-linux       # OpenGL host support
          nixgl.defaultPackage.x86_64-linux             # OpenGL wrapper
        ];
        # System modules and configuration files
        modules = [
          # Core system configuration
          ./configuration.nix                           # Main system configuration
          ./remote-build.nix                            # Remote build settings
          ./secrets.nix                                 # SOPS secrets management
          
          # Platform-specific ESXi configurations
          ./esnixi/boot.nix                             # Boot loader and kernel settings
          ./esnixi/games.nix                            # Gaming optimizations
          ./esnixi/graphics.nix                         # GPU and graphics configuration
          ./esnixi/monitoring.nix                       # System monitoring tools
          ./esnixi/networking.nix                       # Network configuration
          ./esnixi/thunderbolt.nix                      # Thunderbolt support
          ./esnixi/virtualisation.nix                   # Virtualization settings
          
          # External modules
          # niri.nixosModules.niri                      # Niri compositor (disabled)
          protontweaks.nixosModules.protontweaks        # Steam Proton enhancements
          sops-nix.nixosModules.sops                    # Secrets management
          
          # Keyboard remapping (disabled in favor of keyd)
          # toshy.nixosModules.toshy                    # Mac-style keybindings
          
          # Home Manager integration for user environment
          home-manager.nixosModules.home-manager
          {
            # Home Manager configuration options
            home-manager.useGlobalPkgs = true;          # Use system packages in home-manager
            home-manager.useUserPackages = true;        # Install packages to user profile
            home-manager.backupFileExtension = "backup"; # Backup existing files
            home-manager.verbose = true;                # Enable verbose output for debugging
            
            # Pass additional arguments to home-manager modules
            home-manager.extraSpecialArgs = { 
              inherit inputs;                           # Flake inputs
              inherit pkgs-unstable;                    # Unstable package set
              inherit pkgs-old;                         # Legacy package set
            };
            
            # User-specific home-manager configuration
            home-manager.users.celes = import ./home/default.nix;
          }
        ];
      };
      # MacBook T2 configuration
      # Optimized for Apple MacBook with T2 security chip
      macland = 
      let 
        # Package set optimized for Apple hardware with AMD graphics
        pkgs = import inputs.nixpkgs rec {
          inherit system;
          config = {
            # AMD ROCm support for Apple's integrated graphics
            rocmSupport = true;                         # AMD GPU compute support
            allowUnfree = true;                         # Enable proprietary packages
            allowBroken = true;                         # Allow packages marked as broken
            
            # Specific unfree packages whitelist
            allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
              "vscode" "discord" "nvidia-x11" "cudatoolkit" "steam" 
              "steam-original" "steam-run" "cuda_cccl"
            ];

            # Legacy packages for compatibility
            permittedInsecurePackages = [
              "python-2.7.18.7"                        # Legacy Python for compatibility
              "openssl-1.1.1w"                         # Legacy OpenSSL
            ];
          };
          
          # MacBook-specific overlays
          overlays = [
            nixgl.overlay                               # OpenGL support
            (import ./overlays/keyboard-visualizer.nix) # Audio visualizer
            (import ./overlays/debugpy.nix)             # Python debugger
            # (import ./overlays/freerdp.nix)           # Remote desktop (disabled for macOS)
            (import ./overlays/keyd.nix)                # Keyboard daemon for remapping
            (import ./overlays/kubevirt.nix)            # Kubernetes virtualization
            (import ./overlays/materialyoucolor.nix)    # Material You theming
            (import ./overlays/end-4-dots.nix)          # Desktop configuration
            (import ./overlays/latex.nix)               # LaTeX document system
            (import ./overlays/wofi-calc.nix)           # Calculator widget
            (import ./overlays/xivlauncher.nix)         # Final Fantasy XIV launcher
            # (import ./overlays/onnxruntime.nix)       # ONNX runtime (disabled)
            (import ./overlays/helmfile.nix)            # Kubernetes Helm management
            (import ./overlays/t2fanrd.nix)             # T2 fan control daemon
            # (import ./overlays/tinydfr.nix)           # Touch Bar support (disabled)
          ];
        };
        
        # Unstable packages for latest software
        pkgs-unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config = {
            rocmSupport = true;                         # AMD GPU support
            allowUnfree = true;
            allowBroken = true;
          };
        };
        in
        nixpkgs.lib.nixosSystem { 
          # Special arguments for MacBook configuration
          specialArgs = {
            inherit pkgs;                               # Main package set
            inherit pkgs-unstable;                      # Unstable packages
          };
          
          # MacBook-specific system packages
          system.packages = [ 
            anyrun.packages.${system}.anyrun            # Application launcher
            tiny-dfr.packages.${system}.tiny-dfr        # Touch Bar support
          ];
          # MacBook T2 system modules and configuration
          modules = [
            # MacBook-specific hardware configurations
            ./macland/boot.nix                          # Boot configuration for T2 chip
            ./macland/cpu.nix                           # CPU optimizations for Apple silicon
            ./macland/games.nix                         # Gaming setup for macOS compatibility
            ./macland/graphics.nix                      # Graphics drivers for Apple hardware
            ./macland/networking.nix                    # Network configuration including WiFi/Bluetooth
            ./macland/sound.nix                         # Audio system configuration
            ./macland/thunderbolt.nix                   # Thunderbolt support
            ./macland/virtualisation.nix                # Virtualization for Apple hardware
            
            # Shared system configuration
            ./configuration.nix                         # Main system configuration
            ./secrets.nix                               # SOPS secrets management
            
            # Hardware-specific modules
            nixos-hardware.nixosModules.apple-t2        # Apple T2 security chip support
            ./hardware-configuration.nix                # Hardware detection results
            sops-nix.nixosModules.sops                  # Secrets management
            
            # Home Manager integration
            home-manager.nixosModules.home-manager
            {
              # Home Manager configuration for MacBook
              home-manager.useGlobalPkgs = true;        # Use system packages
              home-manager.useUserPackages = true;      # Install to user profile
              home-manager.backupFileExtension = "backup"; # Backup existing files
              home-manager.verbose = true;              # Enable verbose output
              
              # Pass additional arguments to home-manager
              home-manager.extraSpecialArgs = { 
                inherit inputs;                         # Flake inputs
                inherit pkgs-unstable;                  # Unstable packages
                inherit pkgs-old;                       # Legacy packages
              };
              
              # User-specific configuration (shared with ESXi)
              home-manager.users.celes = import ./home/default.nix;
            }
          ];
        };
    };
  };
}
