# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ chaotic, config, lib, nixos-hardware, pkgs, pkgs-stable, pkgs-unstable, ... }:
{
  # Licences.
  nixpkgs.config = {
    allowUnfree = true;
  };  

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
  # Hardware Settings.
  hardware = {
    deviceTree = {
      enable = true;
      filter = "*rpi-5-*.dtb";
    };
  };

  # Udev rules.
  hardware.uinput.enable = true;
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
  services.udev.extraRules = ''
    # HDMI-CEC
    SUBSYSTEM=="vchiq", GROUP="video", MODE="0660", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/vchiq"
    # permissions from https://github.com/graysky2/kodi-standalone-service/blob/master/arm/udev/99-kodi.rules
    #    SUBSYSTEM=="vc-sm",GROUP="video",MODE="0660"
    #    SUBSYSTEM=="tty",KERNEL=="tty[0-9]*",GROUP="tty",MODE="0660"

    # https://github.com/RPi-Distro/raspberrypi-sys-mods/blob/master/etc.armhf/udev/rules.d/99-com.rules#L7
    SUBSYSTEM=="input", GROUP="input", MODE="0660"
    SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"
    SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"
    SUBSYSTEM=="bcm2835-gpiomem", GROUP="gpio", MODE="0660"
    SUBSYSTEM=="rpivid-*", GROUP="video", MODE="0660"
    KERNEL=="vcsm-cma", GROUP="video", MODE="0660"
    SUBSYSTEM=="dma_heap", GROUP="video", MODE="0660"
    SUBSYSTEM=="gpio", GROUP="gpio", MODE="0660"
  '';

  # Logitech.
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

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
  services.displayManager = {
    defaultSession = "hyprland";
  };
  services.xserver.displayManager.gdm = {
      enable = true;
      wayland = true;
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Enlightenment Desktop Environment.
  services.xserver.desktopManager.enlightenment.enable = true;

  programs.hyprland = {
    # Install the packages from nixpkgs
    enable = true;
    package = pkgs-stable.hyprland;
    # Whether to enable Xwayland
    xwayland.enable = true;
  };
  programs.fish.enable = true;
  programs.light.enable = true;
  services.avahi.enable = true;
  # Enable Location.
  services.geoclue2.enable = true;

  # Enable acpid
  services.acpid.enable = true;

  # Argonone.
  services.hardware.argonone = {
    enable = true;
    package = pkgs.argononedOverride;
  };

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
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
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
    fontconfig
    lexend
    nerdfonts
    material-symbols
    bibata-cursors
  ];

  # Extra Groups
  users.groups.mlocate = {};
  users.groups.plocate = {};
  users.groups.libvirt = {};
  users.groups.kvm = {};

  security.sudo.configFile = ''
    root   ALL=(ALL:ALL) SETENV: ALL
    %wheel ALL=(ALL:ALL) SETENV: ALL
    celes  ALL=(ALL:ALL) SETENV: ALL
  '';

  # Gnome Keyring
  services.gnome.gnome-keyring.enable = true;
  # Polkit
  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs-stable.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };
    };
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Gestures.
  services.touchegg.enable = true;

  # Garbage Collection.
  nix.optimise.automatic = true;
 
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.celes = {
    isNormalUser = true;
    description = "Celes Renata";
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" "render" "video" "audio" "libvirt" "docker" "kvm" ];
  };

  users.users.demo = {
    isNormalUser = true;
    initialPassword = "demo";
    description = "Demo User";
    extraGroups = [ "networkmanager" "input" "uinput" "render" "video" "audio" "libvirt" "docker" "kvm" ];
  };
  # List packages installed in system profile. To search, run:
  # Enable Wayland for Electron.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

  # $ nix search wget
  environment.systemPackages = 
  (with pkgs-stable; [
    gtksourceview
  ])

  ++

  (with pkgs-stable; [
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
    alsa-utils

    # System Tools.
    glxinfo
    blueman
    networkmanagerapplet
    nix-index
    mlocate
    barrier
    openssl
    simple-scan
    nixos-generators
    screen 
    btop
    usbutils
    pciutils
    thefuck
    tldr
    bc
    kbd
    imagemagick
    pssh
    ssh-tools

    # Shells.
    fish
    zsh
    bash

    # Development Tools.
    git
    sublime4

    # Kubernetes.
    helm
    k3s

    # Session.
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

    # Wayland.
    xwayland
    brightnessctl
    ydotool
    fcitx5
    wlsunset
    wtype
    wl-clipboard
    xorg.xhost
    wev
    wf-recorder
    mkvtoolnix-cli
    vulkan-tools
    libva-utils
    wofi
    libqalculate
    moonlight-qt
    xfce.thunar
    wayland-scanner
    waypipe
    
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

    # Mac Camera.
    libcamera

    nil
    kubevirt
    foot
    ffmpeg-full
    libspatialaudio
    pulseaudio
    kdenlive
    xwaylandvideobridge
    hyprpaper
    box64
    
    # Media
    jellyfin-media-player
    plex-media-player
    (kodi-wayland.withPackages (kodiPackages: with kodiPackages; [
      inputstream-adaptive
      inputstream-ffmpegdirect
    ]))

    # Kubernetes Tools
    k3s
    (wrapHelm kubernetes-helm {
      plugins = with kubernetes-helmPlugins; [
        helm-secrets
        helm-diff
        helm-s3
        helm-git
      ];
    })
    pkgs-unstable.kubernetes-helm
    pkgs-unstable.helmfile
    pkgs-unstable.kustomize
    pkgs-unstable.kompose
    pkgs.kubevirt
    pkgs-unstable.krew
  ])

  ++

  (with pkgs-unstable; [ 
    # Development Tools
    jetbrains-toolbox-aarch64
    (kodi-wayland.withPackages (kodiPackages: with kodiPackages; [
      inputstream-adaptive
      inputstream-ffmpegdirect
    ]))
   ]);


  xdg.portal = {
    enable = true;
    wlr = {
      enable = true;
      settings.screencast = {
        output_name = "HDMI-A-1";
        max_fps = 30;
        chooser_type = "simple";
        chooser_cmd = "${pkgs-stable.slurp}/bin/slurp -f %o -or";
      };
    };
    config = {
      common = {
        Hyprland = [
          "gtk"
          "hyprland"
          "wlr"
        ];
        #"org.freedesktop.impl.portal.AppChooser"=["kde"];
        # this doesn't work
        #"org.freedesktop.impl.portal.FileChooser"=["kde"];
        #"org.freedesktop.impl.portal.ScreenCast"=["wlr"];
        #"org.freedesktop.impl.portal.Screenshot"=["wlr"];

        "org.freedesktop.impl.portal.ScreenCast"=["hyprland"];
        "org.freedesktop.impl.portal.Screenshot"=["hyprland"];
      };
    };
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-wlr
      #inputs.xdg-desktop-portal-hyprland
    ];
  };


  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}
