# lan-mouse: keyboard/mouse sharing with stabulous (MacBook Pro M5 Max)
# Laptop is to the right of the main monitor, centered vertically.
{ pkgs, ... }:
let
  configFile = pkgs.writeText "lan-mouse-config.toml" ''
    # lan-mouse configuration for esnixi (NixOS desktop)
    # Laptop (stabulous) is to the right, centered vertically.

    port = 4242

    # Laptop on the right
    [[clients]]
    position = "right"
    hostname = "stabulous"
    ips = ["192.168.42.201"]
    port = 4242
    activate_on_startup = true
  '';
in
{
  environment.systemPackages = [ pkgs.lan-mouse ];

  # Open the UDP port for lan-mouse
  networking.firewall.allowedUDPPorts = [ 4242 ];

  # Systemd user service running in daemon mode
  systemd.user.services.lan-mouse = {
    description = "Lan Mouse - keyboard/mouse sharing daemon";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/install -Dm644 ${configFile} %h/.config/lan-mouse/config.toml";
      ExecStart = "${pkgs.lan-mouse}/bin/lan-mouse daemon";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
