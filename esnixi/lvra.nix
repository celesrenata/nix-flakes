{ config, pkgs, lib, ... }:

{
  # WiVRn (Monado-based) is supported natively on NixOS. :contentReference[oaicite:2]{index=2}
  services.wivrn = {
    enable = true;

    # This sets a system default runtime at /etc/xdg/openxr/1/active_runtime.json
    # (LVRA mentions this as one of the supported approaches). :contentReference[oaicite:3]{index=3}
    defaultRuntime = true;
  };

  # Steam: set Pressure-Vessel env var so games can connect to OpenXR runtime. :contentReference[oaicite:4]{index=4}
  programs.steam = {
    enable = true;

    # LVRA recommends putting this into the Steam FHS env. :contentReference[oaicite:5]{index=5}
    #package = pkgs.steam.override {
    #  extraProfile = ''
    #    # Allows Monado/WiVRn OpenXR runtimes to be used by Steam apps
    #    export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
    #
    #    # Optional: LVRA mentions this fixes timezones in VRChat
    #    unset TZ
    #  '';
    #};
  };
}

