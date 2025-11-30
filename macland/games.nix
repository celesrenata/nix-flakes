{ pkgs, pkgs-unstable, ... }:
{
  config = {
    programs.alvr = {
      enable = true;
      package = pkgs.alvr;
    };
    hardware.xpadneo.enable = true;
    environment.systemPackages = with pkgs; [
      # immersed  # Build failure
      heroic
    ];
  };
}
