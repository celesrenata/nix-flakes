# Networking configuration for nixbox (VirtualBox/VMware x86_64 VM)
# Simple NetworkManager setup — hypervisor handles NAT/bridging.

{ ... }:

{
  config = {
    networking.hostName = "nixbox";
    networking.networkmanager.enable = true;

    # Bluetooth (pass-through if hypervisor supports it)
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
