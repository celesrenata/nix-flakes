# System-wide packages and desktop environment components
{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, ... }:

{
  # Desktop environment and Wayland packages
  home.packages = with pkgs; [
    # Wayland and desktop environment
    xdg-desktop-portal-hyprland
    xwayland
    brightnessctl
    wlsunset
    wayland-scanner
    waypipe
    xorg.xhost
    wev
    
    # Desktop utilities
    polkit
    polkit_gnome
    dconf
    killall
    gnome-keyring
    wayvnc
    evtest
    zenity
    linux-pam
    cliphist
    sudo
    ssh-tools
    
    # GTK and GUI libraries
    gtk3
    gtk3.dev
    libappindicator-gtk3.dev
    libnotify.dev
    gtk4
    gtk4.dev
    gjs
    gjs.dev
    gtksourceview
    gtksourceview.dev
    xdg-desktop-portal-gtk
    
    # Non-GTK GUI libraries
    tk
    
    # Desktop integration
    libdbusmenu-gtk3
    upower
    yad
    gobject-introspection
    wrapGAppsHook3
    
    # QT libraries
    libsForQt5.qwt
    
    # GNOME components
    gnome-keyring
    gnome-control-center
    gnome-bluetooth
    gnome-shell
    nautilus
    blueberry
    networkmanager
    
    # AGS and Hyprland dependencies
    coreutils
    cliphist
    curl
    ddcutil
    fuzzel
    fuzzel-emoji
    ripgrep
    gojq
    dart-sass
    axel
    wlogout
    wl-clipboard
    hyprpicker
    gammastep
    libnotify
    bc
    xdg-user-dirs
    
    # Text processing and OCR
    tesseract
    
    # Node.js (required for various desktop components)
    nodejs_20
  ];
}
