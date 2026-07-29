# Gaming configuration for Nigel (Lenovo ideacentre AIO 700-27ISH)
# NVIDIA GTX 950M — adequate for Steam, Proton, and older/indie games
# GTX 950M has 4GB VRAM — suitable for gaming at 1080p

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.my.profiles.games.enable {
    # Ensure /mnt/games is always owned by celes
    systemd.tmpfiles.rules = [ "d /mnt/games 0755 celes users -" ];

    # Steam requirements
    boot.kernel.sysctl."vm.legacy_va_layout" = 0;
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "soft";
        item = "stack";
        value = "8192";
      }
    ];

    hardware.xpadneo.enable = true;
    programs.gamemode.enable = true;
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;
      extraPackages = with pkgs; [
        mesa-demos
        qt6.qtwayland
        nss
      ];
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
  };
}
