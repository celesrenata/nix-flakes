# Hyte Touch Display User Service
{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, ... }:

let
  hytePackage = inputs.hyte-touch-infinite-flakes.packages.${pkgs.system}.touch-widgets;
in
{
  # User service for Hyte touch display with seatd backend
  systemd.user.services.hyte-touch-display = {
    Unit = {
      Description = "Hyte Touch Display User Service";
      After = [ "graphical-session.target" ];
      Wants = [ "graphical-session.target" ];
    };
    
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.gamescope}/bin/gamescope --backend drm --prefer-output DP-3 --force-orientation right -- ${hytePackage}/bin/hyte-touch-interface";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [
        "XDG_DATA_DIRS=${hytePackage}/share:$XDG_DATA_DIRS"
        "WLR_DRM_DEVICES=/dev/dri/card1"
        "LIBSEAT_BACKEND=seatd"
        "SEATD_SOCK=/run/seatd.sock"
      ];
    };
    
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
