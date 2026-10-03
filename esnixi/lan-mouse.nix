# input-leap: KVM switch (replaces lan-mouse)
# Desktop (esnixi) is the server, laptop (stabulous) is the client on the RIGHT.
{ pkgs, config, ... }:
let
  serverConfig = pkgs.writeText "input-leap-server.conf" ''
    section: screens
      esnixi:
      stabulous:
    end

    section: links
      esnixi:
        right (0, 38) = stabulous
      stabulous:
        left = esnixi (0, 38)
    end

    section: options
      screenSaverSync = false
      clipboardSharing = true
    end
  '';

  preStart = pkgs.writeShellScript "input-leap-pre" ''
    mkdir -p /home/celes/.config/InputLeap/SSL/Fingerprints
    cat /run/secrets/input-leap-stabulous-fingerprint > /home/celes/.config/InputLeap/SSL/Fingerprints/TrustedClients.txt
  '';
in
{
  environment.systemPackages = [ pkgs.input-leap ];

  # Open the input-leap port
  networking.firewall.allowedTCPPorts = [ 24800 ];

  # Systemd user service running input-leap server with --no-daemon so systemd tracks the process correctly.
  # Fingerprint stored in sops to survive rebuilds (TrustedClients.txt lives under ~/.config/ which gets overwritten).
  #
  # IMPORTANT: with `--use-ei`, input-leaps injects keyboard/mouse through the
  # compositor's libei/EIS provider (Hyprland's built-in EIS). That EI session
  # is bound to the LIFETIME OF THE COMPOSITOR. When Hyprland restarts — a clean
  # relog OR a crash (observed 2026-09-29 07:45:25: Hyprland dumped core in
  # libeis.so.1, emitting `ei: Disconnected by EIS` here) — input-leaps loses
  # its EIS connection and its logical output collapses to `1x1@-1.-1`. It does
  # NOT re-establish the EI session on its own, and because the *TCP* socket to
  # the client stays ESTAB the process never exits, so `Restart=on-failure`
  # never fires. Result: the KVM link looks "connected" but keyboard/mouse are
  # silently dead on the server screen until the service is manually restarted.
  #
  # Fix (identical to the proven clipboard-sync pattern in this repo — that
  # module carries the canonical write-up):
  #   * PartOf graphical-session.target  -> the service is torn down and brought
  #     back up WITH the compositor session, so a Hyprland restart recycles
  #     input-leaps and it re-attaches to the fresh EIS provider.
  #   * ConditionEnvironment=WAYLAND_DISPLAY -> don't start before the
  #     compositor has published the display env into the user manager
  #     (avoids racing an EI attach against a not-yet-ready compositor).
  #   * an ExecStart wrapper that exports WAYLAND_DISPLAY / XDG_RUNTIME_DIR as a
  #     belt-and-braces guard against the systemd env-import race at login.
  systemd.user.services.input-leap = {
    description = "Input Leap KVM server";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    # Do not start until the compositor has published WAYLAND_DISPLAY into the
    # user manager environment; PartOf + the session coming up will (re)trigger.
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig = {
      ExecStartPre = "${preStart}";
      ExecStart = "${pkgs.writeShellScript "input-leap-server-wrapper" ''
        # Belt-and-braces: guarantee the Wayland env even if the systemd
        # environment import raced us. wayland-1 is this seat's fixed socket.
        export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
        export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/1000}"
        exec ${pkgs.input-leap}/bin/input-leaps --no-daemon --use-ei --config ${serverConfig} --address 0.0.0.0:24800
      ''}";
      Environment = [ "DISPLAY=:0" ];
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
