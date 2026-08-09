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
  systemd.user.services.input-leap = {
    description = "Input Leap KVM server";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStartPre = "${preStart}";
      ExecStart = "${pkgs.input-leap}/bin/input-leaps --no-daemon --config ${serverConfig} --address 0.0.0.0:24800";
      Environment = [ "DISPLAY=:0" ];
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
