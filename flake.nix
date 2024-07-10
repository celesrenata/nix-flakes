{
  description = "NixOS configuration";

  inputs = {
    nyx.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    nur.url = "github:nix-community/NUR";
    anyrun.url = "github:Kirottu/anyrun";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    ags.url = "github:Aylur/ags";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    dream2nix.url = "github:nix-community/dream2nix";
    linux_rpi5.url = "gitlab:vriska/nix-rpi5";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz";
  };

  outputs = inputs@{ linux_rpi5, nixpkgs, nixpkgs-stable, nixpkgs-unstable, nur, anyrun, home-manager, dream2nix, nixos-hardware,fh, nyx, ... }:
  let
    system = "aarch64-linux";
    lib = nixpkgs.lib;
    pkgs-stable = import inputs.nixpkgs-stable {
      inherit system;
      config = {
        allowUnfree = true;
        #allowBroken = true;
        permittedInsecurePackages = [
          "openssl-1.1.1w"
        ];
      };
    };
    pkgs-unstable = import inputs.nixpkgs-unstable {
      inherit inputs;
      inherit system;
      config = {
        allowUnfree = true;
        #allowBroken = true;
      };
      overlays = [
        (import ./overlays/jetbrains-toolbox.nix)
      ];
    };

    pkgs = import inputs.nixpkgs {
      inherit inputs;
      inherit system;
      inherit linux_rpi5;
      config.allowUnfree = true;
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
        (import ./overlays/gnome-network-displays.nix)
        nyx.overlays.default
      ];
    };
  in {
    nixosConfigurations = {
      nixberry = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit fh;
          inherit linux_rpi5;
	        inherit pkgs;
          inherit pkgs-stable;
          inherit pkgs-unstable;
        };
        system.packages = [ anyrun.packages.${system}.anyrun
                          ];
        
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          #./remote-build.nix
          ./nixberry/boot.nix
          ./nixberry/cpu.nix
          {
            environment.systemPackages = [ fh.packages.aarch64-linux.default ];
          }
          ./nixberry/graphics.nix
          #./nixberry/kernel.nix
          ./nixberry/networking.nix
          ./nixberry/virtualisation.nix
          #./nixberry/wireless.nix
          home-manager.nixosModules.home-manager
          #nyx.nixosModules.default
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { 
              inherit inputs;
              inherit pkgs-stable;
              inherit pkgs-unstable;
            };
            home-manager.users.celes = import ./home.nix;
          }
        ];
      };
    };
  };
}
