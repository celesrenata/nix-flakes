{ pkgs, pkgs-unstable, ... }:
{
  config = {
    hardware.xpadneo.enable = true;
    programs.alvr = {
      enable = true;
      package = pkgs-unstable.alvr;
    };
    environment.systemPackages = [
#      pkgs.xivlauncher
    ];
  };
}
