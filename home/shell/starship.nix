# Starship prompt configuration
{ inputs, lib, pkgs, pkgs-unstable, ... }:

{
  # Starship - customizable prompt for any shell
  programs.starship = {
    enable = true;
    # Custom settings
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };
}
