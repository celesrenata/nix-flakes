{ ... }:
{
  config = {
    # Networking.
    networking.hostName = "esnixi"; # Define your hostname.
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable NetworkManager.
    networking.networkmanager.enable = true;

    # Enable Bluetooth
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;
    hardware.enableAllFirmware = true;

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 3216 3658 3659 8082 24800 47984 47989 47990 48010 ];
      allowedTCPPortRanges = [
        { from = 31800; to = 31899; }
        { from = 27015; to = 27030; }
        { from = 27036; to = 27037; }
      ];
      allowedUDPPorts = [ 3216 27036 ];
      allowedUDPPortRanges = [
        { from = 24800; to = 24810; }
        { from = 47998; to = 48000; }
        { from = 8000; to = 8010; }
        { from = 9942; to = 9944; }
        { from = 3658; to = 3659; }
        { from = 27000; to = 27031; }
      ];
    };
  };
}
