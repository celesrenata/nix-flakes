# Desktop theming and appearance configuration
{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, ... }:

{
  # Use system cursor theme to avoid home-manager path issues
  home.sessionVariables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
  };

  # X resources for cursor and DPI
  xresources.properties = {
    "Xcursor.size" = 24;
    "Xft.dpi" = 172;
  };

  # GTK theming packages
  home.packages = with pkgs; [
    # Cursor theme
    bibata-cursors
    
    # Themes
    adw-gtk3
    libsForQt5.qt5ct
    pkgs-old.gradience
    yaru-theme
    
    # Cursors and icons
    bibata-cursors
    
    # Color theming
    matugen  # Material You color generation
    python312Packages.kde-material-you-colors  # KDE Material You theming
  ];
}
