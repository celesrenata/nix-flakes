{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-old.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    nur.url = "github:nix-community/NUR";
    anyrun.url = "github:Kirottu/anyrun";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    ags.url = "github:Aylur/ags";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    dream2nix.url = "github:nix-community/dream2nix";
    linux_rpi5.url = "gitlab:vriska/nix-rpi5";
  };

  outputs = inputs@{ linux_rpi5, nixpkgs, nixpkgs-old, nixpkgs-unstable, nur, anyrun, home-manager, dream2nix, nixos-hardware, ... }:
  let
    system = "aarch64-linux";
    lib = nixpkgs.lib;
    pkgs-old = import inputs.nixpkgs-old {
      inherit system;
      config = {
        allowUnfree = true;
        #allowBroken = true;
      };
    };
    pkgs-unstable = import inputs.nixpkgs-unstable {
      inherit inputs;
      inherit system;
      config = {
        allowUnfree = true;
        #allowBroken = true;
      };
    };

    pkgs = import inputs.nixpkgs {
      inherit system;
      inherit linux_rpi5;
      config.allowUnfree = true;
      config.permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
      config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "vscode"
      ];
      config.allowUnsupportedSystem = true;
      overlays = [
        (import ./overlays/debugpy.nix)
        (import ./overlays/materialyoucolor.nix)
        (import ./overlays/end-4-dots.nix)
        (import ./overlays/wofi-calc.nix)
        (import ./overlays/box64.nix)
        (import ./overlays/argononed.nix)
        (import ./overlays/helmfile.nix)
      ];
    };
  in {
    nixosConfigurations = {
      nixberry = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit linux_rpi5;
	  inherit pkgs;
          inherit pkgs-old;
          inherit pkgs-unstable;
        };
        system.packages = [ anyrun.packages.${system}.anyrun
                          ];
        
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          ./remote-build.nix
          ./nixberry/boot.nix
          ./nixberry/cpu.nix
          ./nixberry/graphics.nix
          #./nixberry/kernel.nix
          ./nixberry/networking.nix
          ./nixberry/virtualisation.nix
          #./nixberry/wireless.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { 
              inherit inputs;
              inherit pkgs-old;
              inherit pkgs-unstable;
            };
            home-manager.users.celes = import ./home.nix;
          }
        ];
      };
    };
  };
}
