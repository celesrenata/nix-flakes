{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    anyrun.url = "github:Kirottu/anyrun";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    anyrun.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nixos-hardware, anyrun, home-manager, ... }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;
    pkgs = import <nixpkgs>;
  in {
    nixosConfigurations = {
      esnixi = nixpkgs.lib.nixosSystem {
        #inherit system;
        system.packages = [ anyrun.packages.${system}.anyrun ];
        modules = [
          /*(args: { nixpkgs.overlays = import ./overlays args; })*/
          ./configuration.nix
          ./hardware-configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.celes = import ./home.nix;
          }
        ];
      };
      macland = nixpkgs.lib.nixosSystem {
        #inherit system;
        system.packages = [ anyrun.packages.${system}.anyrun ];
        modules = [
          /*(args: { nixpkgs.overlays = import ./overlays args; })*/
          ./configuration.nix
          nixos-hardware.nixosModules.apple-t2

          ./hardware-configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.celes = import ./home.nix;
          }
        ];
      };

    };
  };
}
