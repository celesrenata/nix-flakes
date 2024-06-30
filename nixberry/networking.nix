{ ... }:
{
  config = {
    # Networking.
    networking.hostName = "nixberry"; # Define your hostname.
    networking.networkmanager.enable = true;
    #networking.networkmanager.wifi.backend = "iwd";
    #networking.wireless = {
    #networking.wireless.iwd = {
      #enable = true;
      #settings.General.EnableNetworkConfiguration = true;
    #};

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable Bluetooth
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;
    hardware.enableAllFirmware = true;

    fileSystems."/mnt/backups" = {
      device = "192.168.42.8:/volume2/Backups";
      fsType = "nfs";
      options = [ "x-systemd.automount" "noauto" ];
    };

    security.pki.certificateFiles = [
      ../home.crt
    ];
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 4242 7236 7260 8082 24800 47984 47989 47990 48010 ];
      allowedUDPPorts = [ 7236 5353 ];
      allowedUDPPortRanges = [
        { from = 24800; to = 24810; }
        { from = 47998; to = 48000; }
        { from = 8000; to = 8010; }
        { from = 9942; to = 9944; }
      ];
    };
  };
}
