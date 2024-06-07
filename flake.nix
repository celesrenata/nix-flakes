{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    anyrun.url = "github:Kirottu/anyrun";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    #anyrun.inputs.nixpkgs.follows = "nixpkgs";
    nix-gl-host.url = "github:numtide/nix-gl-host";
    nixgl.url = "github:nix-community/nixGL";
    #ags.url = "github:Aylur/ags/main";
    ags.url = "github:gorsbart/ags";


    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    dream2nix.url = "github:nix-community/dream2nix";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = inputs@{ nixpkgs, nixpkgs-old, nixpkgs-unstable, anyrun, home-manager, dream2nix, nixgl, nix-gl-host, nix-vscode-extensions, nixos-hardware, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    pkgs-unstable = import inputs.nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfree = true;
        allowBroken = true;
      };
    };
    pkgs-old = import inputs.nixpkgs-old {
      inherit system;
      config = {
        allowUnfree = true;
        allowBroken = true;
      };
    };
    pkgs = import inputs.nixpkgs rec {
      inherit system;
      config = {
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
        (import ./overlays/keyboard-visualizer.nix)
        (import ./overlays/debugpy.nix)
        (import ./overlays/materialyoucolor.nix)
        (import ./overlays/end-4-dots.nix)
        (import ./overlays/latex.nix)
        (import ./overlays/wofi-calc.nix)
        (import ./overlays/xivlauncher.nix)
        (import ./overlays/onnxruntime.nix)
        (import ./overlays/helmfile.nix)
      ];
    };
  in {
    devShells.x86_64-linux = pkgs.mkShell {
      name = "helmfile devShell";
      nativeBuildInputs = with pkgs; [
        bashInteractive
      ];
      buildInputs = with pkgs; [
        kubernetes-helm-wrapped
        helmfile-wrapped
      ];
    };
    nixosConfigurations = {
      esnixi = nixpkgs.lib.nixosSystem {
        specialArgs = {
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
          ./remote-build.nix
          ./esnixi/boot.nix
          ./esnixi/games.nix
          ./esnixi/graphics.nix
          ./esnixi/networking.nix
          ./esnixi/virtualisation.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { 
              inherit inputs;
              inherit pkgs-unstable;
            };
            home-manager.users.celes = import ./home.nix;
          }
        ];
      };
      macland = nixpkgs.lib.nixosSystem { 
        specialArgs = {
          inherit pkgs;
          inherit pkgs-unstable;
        };
        
        system.packages = [ anyrun.packages.${system}.anyrun  ];
        modules = [
          ./macland/boot.nix
          ./macland/cpu.nix
          ./macland/graphics.nix
          ./macland/networking.nix
          ./macland/sound.nix
          ./macland/thunderbolt.nix
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
