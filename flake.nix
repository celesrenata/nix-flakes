{
  description = "NixOS configuration";

  inputs = {
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/develop";
    nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    nyx.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    nur.url = "github:nix-community/NUR";
    anyrun.url = "github:Kirottu/anyrun";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    fh.url = "https://flakehub.com/f/DeterminateSystems/fh/*.tar.gz";
    dots-hyprland.url = "path:/home/celes/sources/end-4-flakes";
    dots-hyprland.inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    dots-hyprland.inputs.home-manager.follows = "home-manager";
    dots-hyprland-source.url = "github:celesrenata/dots-hyprland/quickshell-locked";
    dots-hyprland-source.flake = false;
  };

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = inputs@{ nixos-raspberrypi, nixpkgs, nur, anyrun, home-manager, nixos-hardware, fh, nyx, dots-hyprland, dots-hyprland-source, ... }:
  let
    system = "aarch64-linux";
    lib = nixpkgs.lib;
  in {
    nixosConfigurations = {
      nixberry = nixos-raspberrypi.lib.nixosSystem {
        specialArgs = {
          inherit nixos-raspberrypi;
          inherit fh;
          inherit inputs;
        };
        
        modules = [
          {  imports = with nixos-raspberrypi.nixosModules; [
              raspberry-pi-5.base
              raspberry-pi-5.page-size-16k
              raspberry-pi-5.display-vc4
              raspberry-pi-5.bluetooth
            ];
            boot.loader.raspberryPi.bootloader = "kernel";
           }
          ./configuration.nix
          ./hardware-configuration.nix
          ./nixberry/configtxt.nix
          ./nixberry/boot.nix
          ./nixberry/cpu.nix
          {
            environment.systemPackages = [ fh.packages.aarch64-linux.default anyrun.packages.${system}.anyrun ];
          }
          ./nixberry/graphics.nix
          ./nixberry/networking.nix
          #           ./toshy.nix
          ./nixberry/virtualisation.nix
          ./remote-build.nix
          home-manager.nixosModules.home-manager
          {
            nixpkgs.overlays = [
              (import ./overlays/openssl-pin.nix)
              dots-hyprland.overlays.default
              (import ./overlays/jetbrains-toolbox.nix)
              (import ./overlays/debugpy.nix)
              (import ./overlays/materialyoucolor.nix)
              (import ./overlays/end-4-dots.nix)
              (import ./overlays/wofi-calc.nix)
              (import ./overlays/argononed.nix)
              (import ./overlays/helmfile.nix)
              (import ./overlays/gnome-network-displays.nix)
              (import ./overlays/fuzzel-emoji.nix)
              nyx.overlays.default
            ];
            nixpkgs.config.allowUnfree = true;
            nixpkgs.config.permittedInsecurePackages = [
              "qtwebengine-5.15.19"
            ];
            nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
              "vscode"
            ];
            nixpkgs.config.allowUnsupportedSystem = true;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { 
              inherit inputs;
            };
            home-manager.users.celes = import ./home.nix;
            #home-manager.users.demo = import ./home-demo.nix;
          }
        ];
      };
    };
  };
}
