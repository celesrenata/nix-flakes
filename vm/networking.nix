# Networking configuration for nixberry (Parallels Desktop aarch64 VM)
# Simple NetworkManager setup — Parallels handles NAT/bridging at the hypervisor level.

{ ... }:

{
  config = {
    networking.hostName = "nixberry";
    networking.networkmanager.enable = true;

    # Bluetooth (Parallels can pass through BT)
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    services.blueman.enable = true;
    hardware.enableAllFirmware = true;

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ 22 5900 ];
    };
  };
}
