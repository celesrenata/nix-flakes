{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    anyrun.url = "github:Kirottu/anyrun";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    #anyrun.inputs.nixpkgs.follows = "nixpkgs";
    #nix-gl-host.url = "github:numtide/nix-gl-host";
    #nixgl.url = "github:nix-community/nixGL";
    ags.url = "github:Aylur/ags";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    dream2nix.url = "github:nix-community/dream2nix";
    #nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
  };

  outputs = inputs@{ nixpkgs, anyrun, home-manager, dream2nix, nixos-hardware, ... }:
  let
    system = "aarch64-linux";
    lib = nixpkgs.lib;
    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "vscode"
      ];
      overlays = [
        (import ./overlays/gnome-pie.nix)
        (import ./overlays/keyboard-visualizer.nix)
        (import ./overlays/toshy.nix)
        (import ./overlays/sunshine.nix)
        (import ./overlays/materialyoucolor.nix)
        (import ./overlays/end-4-dots.nix)
        (import ./overlays/wofi-calc.nix)
        (import ./overlays/xivlauncher.nix)
        (import ./overlays/onnxruntime.nix)
      ];
    };
  in {
    nixosConfigurations = {
      nixberry = nixpkgs.lib.nixosSystem {
        #inherit system;
	specialArgs = {
	  inherit pkgs;
	};
        system.packages = [ anyrun.packages.${system}.anyrun ];
                            #nix-gl-host.defaultPackage.${system}
                            #nixgl.defaultPackage.${system} ];
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          ./nixberry/boot.nix
          ./nixberry/graphics.nix
          ./nixberry/networking.nix
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
