{ config, pkgs, lib, ... }:

let
  pythonWithEvdev = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  
  filterScript = pkgs.writeScript "logi-dictation-filter" ''
    #!${pythonWithEvdev}/bin/python3
    ${builtins.readFile ./scripts/logi-dictation-filter.py}
  '';

  # keyd grabs all physical devices (including consumer control) and outputs
  # through its virtual keyboard. The filter grabs keyd's virtual
  # output, intercepts the Ctrl+MicMute+Ctrl sequence, and emits F20.
  # After keyd's Meta→Control swap, the Logi sequence is:
  #   Control_L tap → MicMute → Control_L tap
  # The script finds the keyd virtual keyboard by name at runtime.
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
    
    # Start after keyd — we grab keyd's virtual output
    after = [ "keyd.service" "systemd-udev-settle.service" "systemd-modules-load.service" ];
    requires = [ "keyd.service" ];
    wants = [ "systemd-udev-settle.service" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pythonWithEvdev}/bin/python3 ${filterScript}";
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
