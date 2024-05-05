{ pkgs, pkgs-unstable, ... }:
{
   imports =
   [ # Include the results of the hardware scan.
     "${pkgs-unstable.path}/nixos/modules/programs/alvr.nix"
   ];
  config = {
    programs.alvr = {
      enable = true;
      package = pkgs-unstable.alvr;
    };
    environment.systemPackages = [
      pkgs.xivlauncher
    ];
  };
}
