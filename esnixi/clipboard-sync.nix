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
  #
  # IMPORTANT: this service runs `wl-paste --watch`, which needs a live
  # Wayland connection to receive clipboard *change* events (wlr-data-control).
  # `After=graphical-session.target` alone is NOT enough: at boot, Hyprland
  # imports WAYLAND_DISPLAY into the systemd --user environment via
  # `dbus-update-activation-environment` only AFTER a `sleep 1` (see
  # home/desktop/hyprland.nix), which races the target being "reached". If the
  # service starts before that import, its wl-paste connects with no usable
  # display and the watcher goes *silently deaf for the life of the process* —
  # it never errors, so `Restart=on-failure` never fires, and the receive-only
  # path (a plain socat listener) keeps working, masking the breakage. This is
  # exactly what happened: 0 outbound frames for days while inbound worked.
  #
  # Fix (matches the proven hyte-touch / projectm pattern in this repo):
  #   * PartOf graphical-session.target so it restarts with the session
  #   * ConditionEnvironment=WAYLAND_DISPLAY so it won't start before the
  #     display env is imported (systemd will (re)start it once available)
  #   * an ExecStart wrapper that explicitly exports WAYLAND_DISPLAY /
  #     XDG_RUNTIME_DIR as a belt-and-braces guard against the import race
  systemd.user.services.clipboard-sync = {
    description = "Bidirectional clipboard sync with macOS peer";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    # Do not start until the compositor has published WAYLAND_DISPLAY into the
    # user manager environment; PartOf + the socket appearing will (re)trigger.
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig = {
      ExecStart = "${pkgs.writeShellScript "clipboard-sync-wrapper" ''
        # Belt-and-braces: guarantee the Wayland env even if the systemd
        # environment import raced us. wayland-1 is this seat's fixed socket.
        export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
        export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/1000}"
        export CLIPBOARD_PORT=24802
        exec ${clipboard-sync}/bin/clipboard-sync-wayland 192.168.42.201
      ''}";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
