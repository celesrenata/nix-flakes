{ pkgs, pkgs-unstable, ... }:
{
  config = {
    programs.alvr = {
      enable = true;
    };
    environment.systemPackages = with pkgs; [
      immersed-vr
    ];
  };
}
