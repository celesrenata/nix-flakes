{ pkgs, ... }:
{
  config = {
    programs.alvr.enable = true;
    environment.systemPackages = [
      pkgs.xivlauncher
    ];
  };
}
