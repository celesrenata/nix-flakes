{ inputs, pkgs, ... }: 
{
  nixpkgs.overlays = [ inputs.niri.overlays.niri ];
  programs.niri.package = pkgs.niri-stable;

#  programs.niri.settings = {
#    outputs."eDP-1".scale = 2.0;
#  };
}

