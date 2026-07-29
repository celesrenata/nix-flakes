# Browsers and web applications
{ inputs, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    # Web browsers
    firefox-bin
    chromium
  ];
}