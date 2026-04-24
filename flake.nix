{
  description = "Personal NixOS Configuration - ESXi Baremetal and MacBook T2 Support";

  # Input sources for the flake
  # This section defines all external dependencies and their versions
  inputs = {
    # Core NixOS packages - using stable, old, and unstable channels
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";              # Main stable channel
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-25.05";          # Previous stable for compatibility
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";  # Latest packages

    # Home Manager for user environment management
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";  # Use same nixpkgs version

    # Hyte Y70 Touch-Infinite Display
    hyte-touch-infinite-flakes.url = "github:celesrenata/hyte-touch-infinite-flakes";
    hyte-touch-infinite-flakes.inputs.nixpkgs.follows = "nixpkgs";

    # Application launchers and desktop utilities
    anyrun.url = "github:Kirottu/anyrun";                          # Application launcher
    # anyrun.inputs.nixpkgs.follows = "nixpkgs";                   # Disabled due to compatibility issues

    # Exo acceleration
    #exo.url = "github:celesrenata/exo/main";

    # Kiro CLI
    kiro-cli.url = "github:celesrenata/kiro-cli-flake";
    kiro-cli.inputs.nixpkgs.follows = "nixpkgs";

    # AI and machine learning tools
    # ComfyUI now available in nixpkgs (PR #441841)
    nix-comfyui.url = "github:utensils/nix-comfyui";
    
    # OneTrainer for diffusion model training
    onetrainer-flake.url = "github:celesrenata/OneTrainer-flake/dev";
    onetrainer-flake.inputs.nixpkgs.follows = "nixpkgs";

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
    protontweaks.url = "git+https://codeberg.org/ribbon-studios/protontweaks";       # Steam Proton tweaks

    # Development tools and environments
    dream2nix.url = "github:nix-community/dream2nix";             # Language-specific package management
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";  # VSCode extensions

    # Desktop shell and widgets (currently using gorsbart fork)
    # ags.url = "github:Aylur/ags/main";                          # Original AGS (disabled)
    ags.url = "github:gorsbart/ags";                              # Fork with additional features

    # Secrets management with SOPS (Secrets OPerationS)
    sops-nix.url = "github:Mic92/sops-nix";                       # Encrypted secrets management
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # AI coding assistant CLI
    cline-cli.url = "github:celesrenata/clinecli-flakes";          # Cline AI coding assistant CLI
    cline-cli.inputs.nixpkgs.follows = "nixpkgs";

    # Keyboard remapping (currently disabled in favor of keyd)
    # toshy.url = "github:celesrenata/toshy/cline";               # Mac-style keybindings for Linux
    # toshy.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Flake outputs - defines the actual configurations and development environments
  outputs = inputs@{ nixpkgs, nixpkgs-old, nixpkgs-unstable, anyrun, home-manager, dream2nix, niri, nixgl, nix-gl-host, protontweaks, nix-vscode-extensions, nixos-hardware, tiny-dfr, dots-hyprland, dots-hyprland-source, sops-nix, hyte-touch-infinite-flakes, nix-comfyui, onetrainer-flake, cline-cli, kiro-cli, ... }:
  let
    lib = nixpkgs.lib;

    # ── Overlay Groups ─────────────────────────────────────────────────
    overlayGroups = import ./overlays/default.nix { inherit inputs; };

    # ── mkPkgs: Package Set Factory ────────────────────────────────────
    # Creates a fully instantiated nixpkgs package set given a system,
    # backend selector, list of overlay group names, and optional extra overlays.
    mkPkgs = { system, backend, groups, extraOverlays ? [] }:
      import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          nvidia.acceptLicense = true;
          cudaSupport = (backend == "cuda");
          rocmSupport = (backend == "rocm");
          permittedInsecurePackages = [
            "python-2.7.18.7"
            "qtwebengine-5.15.19"
            "mbedtls-2.28.10"
          ];
        };
        overlays = builtins.concatLists (map (g: overlayGroups.${g}) groups) ++ extraOverlays;
      };

    # ── mkHost: Host Configuration Factory ─────────────────────────────
    # Creates a complete nixpkgs.lib.nixosSystem configuration for a host.
    mkHost = { hostname, system, backend, groups, extraModules ? [], homeImports ? [], extraOverlays ? [] }:
      let
        # Base package set: no CUDA/ROCm, common + desktop + development + gaming overlays
        pkgsBase = mkPkgs {
          inherit system extraOverlays;
          backend = "cpu";
          groups = [ "common" "desktop" "development" "gaming" ];
        };

        # Accelerator package set: backend-selected, common + ai overlays
        pkgsAccel = mkPkgs {
          inherit system;
          inherit backend;
          groups = [ "common" "ai" ];
        };

        # Legacy packages for compatibility
        pkgsOld = import inputs.nixpkgs-old {
          inherit system;
          config = { allowUnfree = true; };
        };

        # Unstable packages for latest software versions
        pkgsUnstable = import inputs.nixpkgs-unstable {
          inherit system;
          config = { allowUnfree = true; };
        };
      in
      inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs pkgsAccel;
          pkgs-old = pkgsOld;
          pkgs-unstable = pkgsUnstable;
          quickshell = inputs.hyte-touch-infinite-flakes.inputs.quickshell.packages.${system}.default;
        };

        modules = [
          # Set nixpkgs to use our pre-configured base package set
          { nixpkgs.pkgs = pkgsBase; }

          # Core system configuration
          ./configuration.nix

          # Profile option declarations
          ./modules/profiles/options.nix

          # Profile modules
          ./modules/profiles/ai.nix
          ./modules/profiles/development.nix
          ./modules/profiles/video-editing.nix

          # Host-specific extra modules
        ] ++ extraModules ++ [

          # Set profile options and acceleration backend from host matrix
          {
            my.profiles.games.enable = groups.games or false;
            my.profiles.development.enable = groups.development or false;
            my.profiles.videoEditing.enable = groups.videoEditing or false;
            my.profiles.virtualization.enable = groups.virtualization or false;
            my.profiles.ai.enable = groups.ai or false;
            my.acceleration.backend = backend;
          }

          # Home Manager integration for user environment
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.verbose = true;

            home-manager.extraSpecialArgs = {
              inherit inputs;
              pkgs-unstable = pkgsUnstable;
              pkgs-old = pkgsOld;
            };

            home-manager.users.celes = {
              imports = homeImports;
            };
          }
        ];
      };

    # ── Host Matrix ────────────────────────────────────────────────────
    # Declarative mapping of hostnames to backends, profiles, and modules.
    hosts = {
      esnixi = {
        system = "x86_64-linux";
        backend = "cuda";
        groups = {
          games = true;
          development = true;
          videoEditing = true;
          virtualization = true;
          ai = true;
        };
        extraModules = [
          # Platform-specific esnixi configurations
          ./esnixi/hardware-configuration.nix
          ./esnixi/boot.nix
          ./esnixi/games.nix
          ./esnixi/graphics.nix
          ./esnixi/hyte-touch.nix
          ./esnixi/monitoring.nix
          ./esnixi/networking.nix
          ./esnixi/remote-desktop.nix
          ./esnixi/thunderbolt.nix
          ./esnixi/virtualisation.nix
          ./esnixi/lvra.nix
          #./esnixi/exo.nix                            # Disabled: requires exo flake input
          #./esnixi/dcgm-exporter.nix                  # Disabled: dcgm-exporter not in nixpkgs

          # Shared configuration modules
          ./remote-build.nix
          ./secrets.nix

          # CA certificate configuration
          {
            security.pki.certificates = [
              (builtins.readFile ./celestium-ca.crt)
            ];
          }

          # External modules
          hyte-touch-infinite-flakes.nixosModules.hyte-touch
          protontweaks.nixosModules.protontweaks
          sops-nix.nixosModules.sops
        ];
        homeImports = [
          ./home/default.nix
          ./esnixi/hyprland.nix
        ];
      };

      macland = {
        system = "x86_64-linux";
        backend = "rocm";
        groups = {
          games = true;
          development = true;
          videoEditing = false;
          virtualization = true;
          ai = false;
        };
        extraOverlays = [
          (import ./overlays/keyd.nix)
          (import ./overlays/t2fanrd.nix)
          (import ./overlays/tinydfr.nix)
          (import ./overlays/pipewire.nix)
        ];
        extraModules = [
          # Platform-specific macland configurations
          ./macland/boot.nix
          ./macland/cpu.nix
          ./macland/games.nix
          ./macland/graphics.nix
          ./macland/networking.nix
          ./macland/sound.nix
          ./macland/thunderbolt.nix
          ./macland/virtualisation.nix

          # Shared configuration modules
          ./remote-build.nix
          ./secrets.nix

          # CA certificate configuration
          {
            security.pki.certificates = [
              (builtins.readFile ./celestium-ca.crt)
            ];
          }

          # Hardware-specific modules
          nixos-hardware.nixosModules.apple-t2
          ./macland/hardware-configuration.nix
          sops-nix.nixosModules.sops

          # USB device access rules
          {
            services.udev.extraRules = ''
              # Thermaltake RGB devices
              SUBSYSTEM=="usb", ATTR{idVendor}=="264a", MODE="0666"
              SUBSYSTEM=="hidraw", ATTRS{idVendor}=="264a", MODE="0666"
            '';
          }
        ];
        homeImports = [
          ./home/default.nix
          ./macland/hyprland.nix
        ];
      };
    };

  in {
    # Development environments for various projects
    devShells.x86_64-linux.default =
      let
        pkgs-devshell = import inputs.nixpkgs-unstable {
          system = "x86_64-linux";
          config = {
            cudaSupport = true;
            allowUnfree = true;
            allowBroken = true;
          };
        };
      in
      pkgs-devshell.mkShell {
        name = "helmfile devShell";
        nativeBuildInputs = with pkgs-devshell; [
          bashInteractive
        ];
        buildInputs = with pkgs-devshell; [
          kubernetes-helm-wrapped
          helmfile-wrapped
        ];
      };

    # NixOS system configurations generated from host matrix
    nixosConfigurations = builtins.mapAttrs (name: cfg: mkHost (cfg // { hostname = name; })) hosts;
  };
}
