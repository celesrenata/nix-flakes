{ pkgs, ... }:
{
  config = {
    # Networking.
    networking.hostName = "macland"; # Define your hostname.
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    # Enable NetworkManager.
    networking.networkmanager.enable = true;
    networking.networkmanager.wifi.backend = "iwd";

    # Enable Bluetooth
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;
    hardware.enableAllFirmware = true; 

    # Enable Wifi.
    hardware.firmware = [
      (pkgs.stdenvNoCC.mkDerivation {
        name = "brcm-firmware";

        buildCommand = ''
          dir="$out/lib/firmware"
          mkdir -p "$dir"
          cp -r ${./firmware}/* "$dir"
        '';
      })
    ];
    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 4242 47984 47989 47990 48010 ];
      allowedUDPPortRanges = [
        { from = 47998; to = 48000; }
        { from = 8000; to = 8010; }
      ];
    };
  };
}