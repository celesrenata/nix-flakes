# RGB Gradient LED Service
# Cycles case LEDs through material-you wallpaper colors via OpenRGB
{ lib, pkgs, ... }:

let
  pythonWithOpenRGB = pkgs.python312.withPackages (ps: [ ps.openrgb-python ]);
in
{
  home.file.".local/bin/rgb-gradient.py" = {
    source = ../../scripts/rgb-gradient/rgb-gradient.py;
    executable = true;
  };

  systemd.user.services.rgb-gradient = {
    Unit = {
      Description = "RGB Gradient LED cycle from wallpaper colors";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${pythonWithOpenRGB}/bin/python3 %h/.local/bin/rgb-gradient.py";
      Restart = "on-failure";
      RestartSec = "10s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
