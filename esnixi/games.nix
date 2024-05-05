{ pkgs, pkgs-unstable, ... }:
{
  imports =
  [
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
