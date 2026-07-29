# Networking configuration for Nigel (Lenovo ideacentre AIO 700-27ISH)

{ pkgs, ... }:

{
  config = {
    networking.hostName = "nigel";
    networking.networkmanager.enable = true;
    networking.networkmanager.plugins = with pkgs; [
      networkmanager-openvpn
    ];

    # Enable Bluetooth
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;
    hardware.enableAllFirmware = true;

    # DHCP non-blocking
    networking.dhcpcd.wait = "background";
    networking.dhcpcd.extraConfig = ''
      timeout 45
    '';
    systemd.network.wait-online.enable = false;

    # IP forwarding for VM traffic
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    networking.firewall = {
      enable = false;
      allowedTCPPorts = [ 11434 8006 3389 8080 8082 ];
      allowedTCPPortRanges = [
        { from = 27015; to = 27030; }
        { from = 27036; to = 27037; }
      ];
      allowedUDPPortRanges = [
        { from = 8000; to = 8010; }
        { from = 27000; to = 27036; }
      ];
    };
  };
}
