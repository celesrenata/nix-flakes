# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, ... }:
{
  # Licences.
  nixpkgs.config.allowUnfree = true;

  # Inscure packages allowed.
  nixpkgs.config.permittedInsecurePackages = [
    "python-2.7.18.7"
  ];

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Enable Flakes.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.plymouth.enable = true;

  # Udev rules.
  hardware.uinput.enable = true;

  # Set your time zone.

  #services.automatic-timezoned.enable = true;
  #location.provider = "geoclue2";
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the GDM Display Manager.
  services.xserver.displayManager.gdm.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Enlightenment Desktop Environment.
  services.xserver.desktopManager.enlightenment.enable = true;

  programs.hyprland = {
    # Install the packages from nixpkgs
    enable = true;
    # Whether to enable Xwayland
    xwayland.enable = true;
  };

  # Enable Location.
  services.geoclue2.enable = true;

  # Enable acpid
  services.acpid.enable = true;

  # Argonone.
  services.hardware.argonone.enable = true;

  # Configure keymap in X11
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.jack = {
    #jackd.enable = true;
    # support ALSA only programs via ALSA JACK PCM plugin
    alsa.enable = true;
    # support ALSA only programs via loopback device (supports programs like Steam)
    loopback = {
      enable = true;
      # buffering parameters for dmix device to work with ALSA only semi-professional sound programs
      #dmixConfig = ''
      #  period_size 2048
      #'';
    };
  };

  # Enable Fonts.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
  ];

  # Extra Groups
  users.groups.mlocate = {};
  users.groups.plocate = {};

  security.sudo.configFile = ''
    root   ALL=(ALL:ALL) SETENV: ALL
    %wheel ALL=(ALL:ALL) SETENV: ALL
    celes  ALL=(ALL:ALL) SETENV: ALL
  '';

  # Gnome Keyring
  services.gnome.gnome-keyring.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
  services.keyd = {
    enable = true;
    keyboards.mac.settings = {
      main = {
        control = "layer(meta)";
        meta = "layer(control)";
        rightcontrol = "layer(meta)";
      };
      meta = {
        left =  "control-left";
        right = "control-right";
        space = "control-space";
      };
    };
    keyboards.mac.ids = [
      "*"
    ];
  };

  # Gestures.
  services.touchegg.enable = true;

  # Garbage Collection.
  nix.optimise.automatic = true;
 
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.celes = {
    isNormalUser = true;
    description = "Celes Renata";
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" "render" "video" "audio" ];
    packages = with pkgs; [
      firefox
    #  thunderbird
    ];
  };

  # List packages installed in system profile. To search, run:
  # Enable Wayland for Electron.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Editors.
    vim
    
    # Networking Tools.
    wget
    curl
    rsync
    nmap
    tmate

    # Audio.
    ladspaPlugins
    calf
    lsp-plugins
    easyeffects
    alsa-utils

    # System Tools.
    glxinfo
    blueman
    networkmanagerapplet
    nix-index
    mlocate
    barrier
    openssl

    # Shells.
    fish
    zsh
    bash

    # Development Tools.
    git
#    nodejs_21
#    meson
#    gcc13
#    cmake
#    pkg-config
#    glib.dev
#    glib
#    glibc.dev
#    gobject-introspection.dev
#    pango.dev
#    harfbuzz.dev
#    cairo.dev
#    gdk-pixbuf.dev
#    atk.dev
#    libpulseaudio.dev
#    typescript
#    ninja
#    nixStatic.dev
#    node2nix
    nil

    # Session.
    polkit
    polkit_gnome
    dconf
    killall
    gnome.gnome-keyring
    wayvnc
    evtest
    gnome.zenity
    linux-pam
    cliphist
    sudo
    xwaylandvideobridge

    # Wayland.
    xdg-desktop-portal-hyprland
    xwayland
    brightnessctl
    ydotool
    swww
    hyprpaper
    fcitx5
    wlsunset
    wtype
    wl-clipboard
    xorg.xhost
    wev
    wf-recorder
    ffmpeg_5-full
    mkvtoolnix-cli
    vulkan-tools
    libva-utils
    wofi
    libqalculate
    sunshine
    moonlight-qt
    xfce.thunar

    # Media
    plex-media-player
    jellyfin-media-player
    kdenlive
    (kodi-wayland.withPackages (kodiPackages: with kodiPackages; [
      inputstream-adaptive
      inputstream-ffmpegdirect
    ]))
    
    # GTK
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

    # Not GTK.
    tk

    # Terminals.
    kitty
    foot

    # Emulation

    # Mac Sound.
    libspatialaudio
    pulseaudio
    #t2AppleAudioDSP

    # Mac Camera.
    libcamera
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
