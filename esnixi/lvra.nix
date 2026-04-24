{ config, pkgs, lib, ... }:

{
  # Steam: set Pressure-Vessel env var so games can connect to OpenXR runtime. :contentReference[oaicite:4]{index=4}
  programs.steam = {
    enable = true;

    # LVRA recommends putting this into the Steam FHS env. :contentReference[oaicite:5]{index=5}
    package = pkgs.steam.override {
      extraProfile = ''
        # Allows Monado/WiVRn OpenXR runtimes to be used by Steam apps
        export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1

        # Optional: LVRA mentions this fixes timezones in VRChat
        unset TZ
      '';
    };
  };
}

