{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    anyrun.url = "github:Kirottu/anyrun";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    #anyrun.inputs.nixpkgs.follows = "nixpkgs";
    nix-gl-host.url = "github:numtide/nix-gl-host";
    nixgl.url = "github:nix-community/nixGL";
    ags.url = "github:Aylur/ags";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    dream2nix.url = "github:nix-community/dream2nix";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = inputs@{ nixpkgs, anyrun, home-manager, dream2nix, nixgl, nix-gl-host, nix-vscode-extensions, nixos-hardware, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    pkgs = import inputs.nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        btop = {
          cudaSupport = true;
        };
        onnxruntime = {
          cudaSupport = true;
        };
        sunshine = {
          cudaSupport = true;
          cudaCapabilities = [ "12.2" ];
          cudaEnableForwardCompat = false;
          allowUnfree = true;
        };
        allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
          "vscode" "discord" "nvidia-x11" "cudatoolkit" "steam" "steam-original" "steam-run"
        ];
      };
      overlays = [
        nixgl.overlay
        (import ./overlays/gnome-pie.nix)
        (import ./overlays/keyboard-visualizer.nix)
        (import ./overlays/toshy.nix)
        (import ./overlays/materialyoucolor.nix)
        (import ./overlays/end-4-dots.nix)
        (import ./overlays/wofi-calc.nix)
        (import ./overlays/xivlauncher.nix)
        (import ./overlays/onnxruntime.nix)
      ];
    };
  in {
    nixosConfigurations = {
      esnixi = nixpkgs.lib.nixosSystem {
        #inherit system;
	specialArgs = {
	  inherit pkgs;
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
          ./esnixi/networking.nix
          ./esnixi/virtualisation.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.celes = import ./home.nix;
          }
        ];
      };
      macland = nixpkgs.lib.nixosSystem { 
        specialArgs = {
          inherit pkgs;
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
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.celes = import ./home.nix;
          }
        ];
      };
    };
  };
}
