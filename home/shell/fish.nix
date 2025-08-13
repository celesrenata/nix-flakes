# Fish shell configuration
{ inputs, lib, pkgs, pkgs-unstable, ... }:

{
  # Fish shell configuration (manual, since we disabled copyFishConfig)
  programs.fish = {
    enable = true;
    shellInit = ''
      # Source the dots-hyprland fish config
      if test -f ${inputs.dots-hyprland-source}/.config/fish/config.fish
        source ${inputs.dots-hyprland-source}/.config/fish/config.fish
      end
    '';
  };
}
