# Home directory file management and dotfiles
{ inputs, lib, pkgs, pkgs-unstable, ... }:

let
  celes-dots = pkgs.fetchFromGitHub {
    owner = "celesrenata";
    repo = "dotfiles";
    rev = "84ffef9c6f9c0fb204cf7e3561d6dd05434b115c";
    sha256 = "sha256-RwK8A7kBCrNlU+Y7Nfc0P0jK8WO6d3fo49T65CZo+F8=";
  };
  
  wofi-calc = pkgs.fetchFromGitHub {
    owner = "Zeioth";
    repo = "wofi-calc";
    rev = "edd316f3f40a6fcb2afadf5b6d9b14cc75a901e0";
    sha256 = "sha256-y8GoTHm0zPkeXhYS/enNAIrU+RhrUMnQ41MdHWWTPas=";
  };
  
  winapps = pkgs.fetchFromGitHub {
    owner = "celesrenata";
    repo = "winapps";
    rev = "0319c70fa0dec2da241e9a4b4e35a164f99d6307";
    sha256 = "sha256-+ZAtEDrHuLJBzF+R6guD7jYltoQcs88qEMvvpjiAXqI=";
  };
in
{
  # Dotfiles and configuration files
  home.file."Backgrounds" = {
    source = celes-dots + "/Backgrounds";
    recursive = true;
  }; 
  
  # Winapps configuration
  home.file."winapps/pkg" = {
    source = winapps;
    recursive = true;
    executable = true;
  };
  
  home.file."winapps/runmefirst.sh" = {
    source = winapps + "/runmefirst.sh";
  };
  
  # Staging directory for mutable configs (used by initialSetup.sh)
  home.file.".configstaging/quickshell" = {
    source = inputs.dots-hyprland-source + "/.config/quickshell";
    recursive = true;
  };
  
  home.file.".configstaging/matugen" = {
    source = inputs.dots-hyprland-source + "/.config/matugen";
    recursive = true;
  };
  
  home.file.".configstaging/hypr/hyprland" = {
    source = inputs.dots-hyprland-source + "/.config/hypr/hyprland";
    recursive = true;
  };

  # Local bin scripts
  home.file.".local/bin/initialSetup.sh" = {
    source = celes-dots + "/.local/bin/initialSetup.sh";
  };
  
  home.file.".local/bin/sunshine" = {
    source = celes-dots + "/.local/bin/sunshineFixed";
  };
  
  home.file.".local/bin/agsAction.sh" = {
    source = celes-dots + "/.local/bin/agsAction.sh";
  };
  
  home.file.".local/bin/regexEscape.sh" = {
    source = celes-dots + "/.local/bin/regexEscape.sh";
  };
  
  home.file.".local/bin/wofi-calc" = {
    source = wofi-calc + "/wofi-calc.sh";
  };
  
  # Fish auto-completion scripts (manual copy to avoid fish_variables conflicts)
  home.file.".config/fish/auto-Hypr.fish" = {
    source = "${inputs.dots-hyprland-source}/.config/fish/auto-Hypr.fish";
  };

  # Commented out Toshy-related files (replaced by keyd)
  # These are kept as comments for reference in case you want to re-enable Toshy
  
  # home.file.".configstaging/toshy/toshy_config.py" = {
  #   source = "${pkgs.toshy}/toshy_config.py";
  # };
  # home.file.".configstaging/toshy/toshy_user_preferences.sqlite" = {
  #   source = "${pkgs.toshy}/toshy_user_preferences.sqlite";
  # };
  
  # Multiple Toshy bin scripts would go here...
  # (commented out for brevity - they're all in the original file)
}
