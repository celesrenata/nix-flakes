# Media applications and multimedia tools
{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, ... }:

{
  # OBS Studio configuration
  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
      obs-vaapi
      wlrobs
      obs-vintage-filter
    ];
  };

  # Media packages
  home.packages = with pkgs; [
    # Media players
    mpv
    vlc
    plex-desktop
    jellyfin-media-player

    # Audio tools
    pavucontrol
    wireplumber
    playerctl
    
    # Audio effects and plugins
    libdbusmenu-gtk3
    
    # Image and video editing
    pkgs-old.gimp
    darktable
    blender
    kdePackages.kdenlive
    
    # Image processing
    imagemagick
    
    # Screenshot and recording tools
    swappy
    wf-recorder
    grim
    slurp
    
    # Wallpaper management
    swww
    
    # Gaming and entertainment
    antimicrox
    
    # Music applications
    spotify
    discord
    signal-desktop
    tidal-hifi
  ] ++ (with pkgs-unstable; [
    # Unstable media packages
    lan-mouse
  ]);
}
