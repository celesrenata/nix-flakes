# Fish shell configuration
{ inputs, lib, pkgs, ... }:

{
  # Fish shell configuration (manual, since we disabled copyFishConfig)
  programs.fish = {
    enable = true;
    shellInit = ''
      # Source the dots-hyprland fish config
      if test -f ${inputs.dots-hyprland-source}/.config/fish/config.fish
        source ${inputs.dots-hyprland-source}/.config/fish/config.fish
      end

      # GitHub PAT from sops secret for MCP servers (Codex, Kiro)
      if test -r /run/secrets/github_token
        set -gx GITHUB_PERSONAL_ACCESS_TOKEN (cat /run/secrets/github_token)
      end
    '';
  };
}
