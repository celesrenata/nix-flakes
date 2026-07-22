{ config, pkgs, lib, ... }:

let
  pythonWithEvdev = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  
  filterScript = pkgs.writeScript "logi-dictation-filter" ''
    #!${pythonWithEvdev}/bin/python3
    ${builtins.readFile ./scripts/logi-dictation-filter.py}
  '';

  # Device paths for the Logitech USB Receiver
  # event0 = main keyboard (sends Meta key taps)
  # event2 = consumer control (sends MicMute)
  kbdDevice = "/dev/input/by-id/usb-Logitech_USB_Receiver-event-kbd";
  consumerDevice = "/dev/input/event2";  # Consumer Control (no by-id symlink)
in
{
  # Ensure uinput module is loaded for virtual device creation
  boot.kernelModules = [ "uinput" ];
  
  # Give the service access to uinput
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="input"
  '';

  systemd.services.logi-dictation-filter = {
    description = "Logitech Dictation Button Filter (Meta+MicMute+Meta → F20)";
    wantedBy = [ "multi-user.target" ];
    
    # Start before keyd so we grab the raw devices first
    before = [ "keyd.service" ];
    wants = [ "systemd-udev-settle.service" ];
    after = [ "systemd-udev-settle.service" "systemd-modules-load.service" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pythonWithEvdev}/bin/python3 ${filterScript} ${kbdDevice} ${consumerDevice}";
      Restart = "always";
      RestartSec = 2;
      
      # Run as root to access input devices and uinput
      User = "root";
      
      # Minimal hardening — needs full device access
      PrivateTmp = true;
      ProtectHome = true;
    };
  };
}
