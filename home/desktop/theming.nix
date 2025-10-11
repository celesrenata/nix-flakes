# Desktop theming and appearance configuration
{ inputs, lib, pkgs, pkgs-unstable, ... }:

{
  # Cursor configuration
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # Fix cursor theme path
  xdg.dataFile."icons/Bibata-Modern-Classic".source = "${pkgs.bibata-cursors}/share/icons/Bibata-Modern-Classic";

  # X resources for cursor and DPI
  xresources.properties = {
    "Xcursor.size" = 24;
    "Xft.dpi" = 172;
  };

  # GTK theming packages
  home.packages = with pkgs; [
    # Themes
    adw-gtk3
    libsForQt5.qt5ct
    gradience
    yaru-theme
    
    # Cursors and icons
    bibata-cursors
    
    # Color theming
    matugen  # Material You color generation
  ];
}
