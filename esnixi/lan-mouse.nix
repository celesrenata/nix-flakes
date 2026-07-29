# input-leap: KVM switch (replaces lan-mouse)
# Desktop (esnixi) is the server, laptop (stabulous) is the client on the RIGHT.
{ pkgs, ... }:
let
  serverConfig = pkgs.writeText "input-leap-server.conf" ''
    section: screens
      esnixi:
      stabulous:
    end

    section: links
      esnixi:
        right = stabulous
      stabulous:
        left = esnixi
    end

    section: options
      screenSaverSync = false
      clipboardSharing = true
    end
  '';
in
{
  environment.systemPackages = [ pkgs.input-leap ];

  # Open the input-leap port
  networking.firewall.allowedTCPPorts = [ 24800 ];

  # Systemd user service running input-leap server with EI backend for Wayland/Hyprland
  systemd.user.services.input-leap = {
    description = "Input Leap KVM server";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.input-leap}/bin/input-leaps --no-daemon --use-ei --config ${serverConfig} --address 0.0.0.0:24800";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
