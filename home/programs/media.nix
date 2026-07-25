# Media applications and multimedia tools
{ inputs, lib, pkgs, ... }:

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
    jellyfin-media-player

    # Audio tools
    pavucontrol
    wireplumber
    playerctl
    
    # Audio effects and plugins
    libdbusmenu-gtk3
    
    # Image and video editing
    gimp
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
    awww
    
    # Gaming and entertainment
    antimicrox
    
    # Music applications
    signal-desktop
    lan-mouse
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    plex-desktop
    spotify
    discord
    tidal-hifi
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isAarch64 [
    legcord
  ];
}
