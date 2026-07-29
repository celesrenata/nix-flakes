# Clipboard sync for Input Leap (EI backend doesn't support clipboard on Wayland)
{ pkgs, ... }:
let
  clipboard-sync-recv = pkgs.writeShellApplication {
    name = "clipboard-sync-recv-wayland";
    runtimeInputs = with pkgs; [ wl-clipboard coreutils gnutar findutils ];
    excludeShellChecks = [ "SC2016" ];
    text = builtins.readFile ./clipboard-sync-recv-wayland;
  };

  clipboard-sync = pkgs.writeShellApplication {
    name = "clipboard-sync-wayland";
    runtimeInputs = with pkgs; [ socat wl-clipboard coreutils gnutar findutils clipboard-sync-recv ];
    excludeShellChecks = [ "SC2016" ];
    text = builtins.readFile ./clipboard-sync-wayland;
  };
in
{
  environment.systemPackages = [ clipboard-sync clipboard-sync-recv ];

  # Open the clipboard sync port
  networking.firewall.allowedTCPPorts = [ 24802 ];

  # Systemd user service
  systemd.user.services.clipboard-sync = {
    description = "Bidirectional clipboard sync with macOS peer";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${clipboard-sync}/bin/clipboard-sync-wayland 192.168.42.201";
      Restart = "on-failure";
      RestartSec = 3;
      Environment = [
        "CLIPBOARD_PORT=24802"
      ];
    };
  };
}
