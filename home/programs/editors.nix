# Editors and code tools
{ inputs, lib, pkgs, ... }:

{
  # VSCode configuration
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      oderwat.indent-rainbow
      eamodio.gitlens
      jnoortheen.nix-ide
    ];
  };

  # Git configuration
  programs.git = {
    enable = true;
    lfs.enable = true;
  };
}