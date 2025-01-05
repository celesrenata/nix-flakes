{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-24.11";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    anyrun.url = "github:Kirottu/anyrun";
    nix-comfyui.url = "github:haras-unicorn/nix-comfyui";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    #anyrun.inputs.nixpkgs.follows = "nixpkgs";
    niri.url = "github:sodiboo/niri-flake";
    nix-gl-host.url = "github:numtide/nix-gl-host";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";    
    nixgl.url = "github:nix-community/nixGL";
    #ags.url = "github:Aylur/ags/main";
    ags.url = "github:gorsbart/ags";
    tiny-dfr.url = "github:sharpenedblade/tiny-dfr";
    dream2nix.url = "github:nix-community/dream2nix";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = inputs@{ nixpkgs, nixpkgs-old, nixpkgs-unstable, anyrun, nix-comfyui, home-manager, dream2nix, niri, nixgl, nix-gl-host, nix-vscode-extensions, nixos-hardware, tiny-dfr, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    pkgs-old = import inputs.nixpkgs-old {
      inherit system;
      config = {
        allowUnfree = true;
        allowBroken = true;
      };
    };
    pkgs-devshell = import inputs.nixpkgs-unstable {
      inherit system;
      config = {
        cudaSupport = true;
        allowUnfree = true;
        allowBroken = true;
      };
    };

  in {
    devShells.x86_64-linux = pkgs-devshell.mkShell {
      name = "helmfile devShell";
      nativeBuildInputs = with pkgs-devshell; [
        bashInteractive
      ];
      buildInputs = with pkgs-devshell; [
        kubernetes-helm-wrapped
        helmfile-wrapped
      ];
    };
    nixosConfigurations = {
      esnixi =
      let
      pkgs = import inputs.nixpkgs rec {
        inherit system;
        config = {
          cudaSupport = true;
          allowUnfree = true;
          allowBroken = true;
          allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
            "vscode" "discord" "nvidia-x11" "cudatoolkit" "steam" "steam-original" "steam-run" "cuda_cccl"
          ];
          permittedInsecurePackages = [
            "python-2.7.18.7"
            "openssl-1.1.1w"
          ];
        };
        overlays = [
          nixgl.overlay
          #inputs.niri.overlays.niri
          inputs.nix-comfyui.overlays.default
          #(import ./overlays/cider.nix)
          (import ./overlays/keyboard-visualizer.nix)
          (import ./overlays/debugpy.nix)
          (import ./overlays/freerdp.nix)
          (import ./overlays/materialyoucolor.nix)
          (import ./overlays/end-4-dots.nix)
          (import ./overlays/nix-static.nix)
          (import ./overlays/freerdp.nix)
          (import ./overlays/kubevirt.nix)
          (import ./overlays/jetbrains-toolbox.nix)
          (import ./overlays/latex.nix)
          #(import ./overlays/nmap.nix)
          (import ./overlays/wofi-calc.nix)
          #(import ./overlays/xivlauncher.nix)
          #(import ./overlays/onnxruntime.nix)
          (import ./overlays/helmfile.nix)
          (import ./overlays/background-removal.nix)
        ];
      };
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
      specialArgs = {
        #inherit niri;
        inherit pkgs;
        inherit pkgs-unstable;
      };
      system.packages = [ anyrun.packages.${system}.anyrun
                          nix-gl-host.defaultPackage.x86_64-linux
                          nixgl.defaultPackage.x86_64-linux
                        ];
      modules = [
        ./configuration.nix
        ./hardware-configuration.nix
        ./esnixi/boot.nix
        ./esnixi/games.nix
        ./esnixi/graphics.nix
        ./esnixi/monitoring.nix
        ./esnixi/networking.nix
        ./esnixi/virtualisation.nix
        #niri.nixosModules.niri
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { 
            inherit inputs;
            inherit pkgs-unstable;
            inherit pkgs-old;
          };
          home-manager.users.celes = import ./home.nix;
        }
      ];
    };
    macland = 
      let 
        pkgs = import inputs.nixpkgs rec {
          inherit system;
          config = {
            rocmSupport = true;
            allowUnfree = true;
            allowBroken = true;
            allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
              "vscode" "discord" "nvidia-x11" "cudatoolkit" "steam" "steam-original" "steam-run" "cuda_cccl"
            ];

            permittedInsecurePackages = [
              "python-2.7.18.7"
              "openssl-1.1.1w"
            ];
          };
          overlays = [
            nixgl.overlay
            inputs.nix-comfyui.overlays.default
            (import ./overlays/keyboard-visualizer.nix)
            (import ./overlays/debugpy.nix)
            (import ./overlays/freerdp.nix)
            (import ./overlays/keyd.nix)
            (import ./overlays/kubevirt.nix)
            (import ./overlays/materialyoucolor.nix)
            (import ./overlays/end-4-dots.nix)
            (import ./overlays/latex.nix)
            (import ./overlays/wofi-calc.nix)
            (import ./overlays/xivlauncher.nix)
            #(import ./overlays/onnxruntime.nix)
            (import ./overlays/helmfile.nix)
            (import ./overlays/t2fanrd.nix)
            #(import ./overlays/tinydfr.nix)
          ];
        };
        pkgs-unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config = {
            rocmSupport = true;
            allowUnfree = true;
            allowBroken = true;
          };
        };
        in
        nixpkgs.lib.nixosSystem { 
        specialArgs = {
          inherit pkgs;
          inherit pkgs-unstable;
        };
        
        system.packages = [ 
          anyrun.packages.${system}.anyrun
          tiny-dfr.packages.${system}.tiny-dfr
        ];
        modules = [
          ./macland/boot.nix
          ./macland/cpu.nix
          ./macland/games.nix
          ./macland/graphics.nix
          ./macland/networking.nix
          ./macland/sound.nix
          ./macland/thunderbolt.nix
          ./macland/virtualisation.nix
          ./configuration.nix
          nixos-hardware.nixosModules.apple-t2
          ./hardware-configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { 
              inherit inputs;
              inherit pkgs-unstable;
              inherit pkgs-old;
            };
            home-manager.users.celes = import ./home.nix;
          }
        ];
      };
    };
  };
}
