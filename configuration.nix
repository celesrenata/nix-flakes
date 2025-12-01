# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ niri, pkgs, pkgs-old, pkgs-unstable, inputs, ... }:
{
  # Licences.
  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "x86-64-v3";

  imports =
    [ # Include the results of the hardware scan.
      #"${pkgs-unstable}/nixos/modules/programs/alvr.nix"
      # Hardware-configuration.nix is imported per-host in flake.nix
    ];

  environment.localBinInPath = true;
  # Enable Flakes.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Bootloader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  #boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_6;
  boot.plymouth.enable = true;
  # Use the Grub EFI boot loader.

  # Certificate management via sops-nix
  # Temporarily disabled during initial build to avoid chicken-and-egg problem
  # security.pki.certificateFiles = [
  #   "/run/secrets/home.crt"
  # ];
  security.pam.loginLimits = [
    {domain = "*"; item = "stack"; type = "-"; value = "unlimited";}
  ];
  # Udev rules.
  # hardware.uinput.enable = true;

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
  services.xserver.displayManager = {
    gdm.enable = true;
    gdm.autoSuspend = false;
    #setupCommands = "export WLR_BACKENDS=headless";
    #autoLogin.enable = true;
    #autoLogin.user = "celes";
  };

  services.displayManager.defaultSession = "hyprland";
  
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Enlightenment Desktop Environment.
  #services.xserver.desktopManager.enlightenment.enable = true;

  # Enable OpenRGB.
  services.hardware.openrgb.enable = true;

  programs.hyprland = {
    # Install the packages from nixpkgs
    enable = true;
    package = pkgs-unstable.hyprland;
    portalPackage = pkgs-unstable.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

#  services.monado = {
#    enable = true;
#    defaultRuntime = true; # Register as default OpenXR runtime
#  };
#
#  systemd.user.services.monado.environment = {
#    STEAMVR_LH_ENABLE = "1";
#    XRT_COMPOSITOR_COMPUTE = "1";
#    WMR_HANDTRACKING = "0";
#  };

  services.wivrn = {
    enable = true;
    openFirewall = true;
    package = pkgs-unstable.wivrn;  
    # Write information to /etc/xdg/openxr/1/active_runtime.json, VR applications
    # will automatically read this and work with WiVRn (Note: This does not currently
    # apply for games run in Valve's Proton)
      defaultRuntime = true;
  
    # Run WiVRn as a systemd service on startup
    autoStart = true;

    # Config for WiVRn (https://github.com/WiVRn/WiVRn/blob/master/docs/configuration.md)
    config = {
      enable = true;
      json = {
        # 1.0x foveation scaling
        scale = 1.0;
        # 100 Mb/s
        bitrate = 100000000;
        encoders = [
          {
            encoder = "vaapi";
            codec = "h265";
            # 1.0 x 1.0 scaling
            width = 1.0;
            height = 1.0;
            offset_x = 0.0;
            offset_y = 0.0;
          }
        ];
      };
    };
  };

  #programs.niri = {
  #  enable = true;
  #  package = niri.packages.x86_64-linux.niri-unstable;
  #};

  programs.fish = {
    enable = true;
  };

  # Enable Location.
  services.geoclue2.enable = true;

  # Enable acpid
  services.acpid.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.gutenprint ];
  hardware.sane.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.fwupd.enable = true;

  # Enable sound with pipewire.
  #sound.enable = true;
  services.pulseaudio.enable = false;
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
    noto-fonts-color-emoji
    dejavu_fonts
    _0xproto
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
    fontconfig
    lexend
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.space-mono
    material-symbols
    bibata-cursors
  ];

  programs.git = {
    enable = true;
    lfs.enable = true;
  };

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

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
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

  # Gestures with custom configuration
  services.touchegg.enable = true;
  
  # System-wide touchegg configuration file
  environment.etc."touchegg/touchegg.conf".text = ''
    <touchégg>
      <settings>
        <property name="animation_delay">150</property>
        <property name="action_execute_threshold">80</property>
        <property name="color">auto</property>
        <property name="borderColor">auto</property>
      </settings>
      <application name="All">
        <!-- 3-finger pinch in: Close window -->
        <gesture type="PINCH" fingers="3" direction="IN">
          <action type="CLOSE_WINDOW">
            <animate>true</animate>
            <color>F84A53</color>
            <borderColor>F84A53</borderColor>
          </action>
        </gesture>
        
        <!-- 2-finger tap: Right click -->
        <gesture type="TAP" fingers="2" direction="UNKNOWN">
          <action type="MOUSE_CLICK">
            <button>3</button>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 3-finger click: Middle click (Hyprland handles the dragging) -->
        <gesture type="CLICK" fingers="3" direction="UNKNOWN">
          <action type="MOUSE_CLICK">
            <button>2</button>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger pinch in: Fullscreen mode 0 -->
        <gesture type="PINCH" fingers="4" direction="IN">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch fullscreen 0</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger pinch out: Fullscreen mode 1 -->
        <gesture type="PINCH" fingers="4" direction="OUT">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch fullscreen 1</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 3-finger swipe up: Show overview -->
        <gesture type="SWIPE" fingers="3" direction="UP">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch global quickshell:overviewToggle</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 3-finger swipe down: Show all windows -->
        <gesture type="SWIPE" fingers="3" direction="DOWN">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch overview</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger swipe left: Move window left -->
        <gesture type="SWIPE" fingers="4" direction="LEFT">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch movewindow l</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger swipe right: Move window right -->
        <gesture type="SWIPE" fingers="4" direction="RIGHT">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch movewindow r</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger swipe up: Move window up -->
        <gesture type="SWIPE" fingers="4" direction="UP">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch movewindow u</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
        
        <!-- 4-finger swipe down: Move window down -->
        <gesture type="SWIPE" fingers="4" direction="DOWN">
          <action type="RUN_COMMAND">
            <command>hyprctl dispatch movewindow d</command>
            <repeat>false</repeat>
            <animation>NONE</animation>
            <on>begin</on>
          </action>
        </gesture>
      </application>
      
    </touchégg>
  '';

  # Garbage Collection.
  nix.optimise.automatic = true;
 
  # Enable Docker with NVIDIA support
  virtualisation.docker.enable = true;
  #programs.steam.package = pkgs.steam.override {
  #  extraPkgs = pkgs: [
  #    pkgs.steamcmd
  #    pkgs.glxinfo
  #    pkgs.steam-tui
  #  ];
  #};
  programs.ccache.enable = true;
  programs.nh.enable = true;
  programs.java.enable = true;
  programs.adb.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamemode.enable = true;
  programs.steam = {
    enable = true;
    extraPackages = with pkgs; [
      mesa-demos
      qt6.qtwayland
      nss
      xorg.libxkbfile
      kdePackages.qtwayland
      libsForQt5.qt5.qtwayland
      mangohud
      gamemode
    ];
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };
  hardware.steam-hardware.enable = true;
  
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.celes = {
    isNormalUser = true;
    description = "Celes Renata";
    extraGroups = [ "networkmanager" "scanner" "lp" "wheel" "input" "uinput" "render" "video" "audio" "docker" "libvirt" "kvm" "vboxusers" "adbusers" "gamemode" ];
    packages = with pkgs; [
      firefox-bin
    #  thunderbird
    ];
  };

  # Shell aliases for OneTrainer
  environment.shellAliases = {
    onetrainer = "nix run github:celesrenata/OneTrainer-flake";
    onetrainer-ui = "nix run github:celesrenata/OneTrainer-flake#onetrainer-ui";
    onetrainer-cli = "nix run github:celesrenata/OneTrainer-flake#onetrainer-cli";
    onetrainer-convert = "nix run github:celesrenata/OneTrainer-flake#onetrainer-convert";
  };

  # List packages installed in system profile. To search, run:
  # Enable Wayland for Electron.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

  # $ nix search wget
  environment.systemPackages = with pkgs; [
    bibata-cursors
    # Editors.
    vim
    
    # AI Tools
    inputs.cline-cli.packages.x86_64-linux.default
    
    # Networking Tools.
    wget
    curl
    rsync
    nmap
    pssh
    tmate

    # Audio.
    ladspaPlugins
    calf
    lsp-plugins
    easyeffects
    alsa-utils

    # System Tools.
    mesa-demos
    blueman
    networkmanagerapplet
    kdePackages.kcmutils  # Provides kcmshell6 for quickshell
    kdePackages.kde-cli-tools  # KDE CLI tools for quickshell
    kdePackages.plasma-nm  # KDE network manager for quickshell
    kdePackages.bluedevil  # KDE bluetooth manager for quickshell
    kdePackages.bluez-qt  # Bluetooth QML module
    kdePackages.plasma-workspace  # Plasma private modules
    nix-index
    mlocate
    util-linux
    openssl
    xsane
    simple-scan
    btop
    screen
    freerdp
    mako
    keymapp
    android-tools

    # Shells.
    fish
    zsh
    bash

    # Kubernetes Tools.
    k3s
    (wrapHelm pkgs-unstable.kubernetes-helm {
      plugins = with pkgs-unstable.kubernetes-helmPlugins; [
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
    pkgs-unstable.kubevirt
    pkgs-unstable.krew

    # Steam Tools.
    steam-tui
    steamcmd
    mangohud
    gamemode
    protonup-qt
    lutris
    bottles
    heroic

    # Development Tools.
    #android-studio-full
    amazon-q-cli
    jetbrains-toolbox
    nodejs_20
    meson
    gcc13
    cmake
    pkg-config
    glib.dev
    glib
    glibc.dev
    gobject-introspection.dev
    openjdk
    pango.dev
    harfbuzz.dev
    cairo.dev
    gdk-pixbuf.dev
    atk.dev
    libpulseaudio.dev
    typescript
    ninja
    #nixStatic.dev
    node2nix
    nil
    sublime4
    #(pkgs.comfyuiPackages.comfyui.override {
    #  extensions = [
    #    pkgs.comfyuiPackages.extensions.acly-inpaint
    #    pkgs.comfyuiPackages.extensions.acly-tooling
    #    pkgs.comfyuiPackages.extensions.cubiq-ipadapter-plus
    #    pkgs.comfyuiPackages.extensions.fannovel16-controlnet-aux
    #  ];
    #  commandLineArgs = [
    #    "--preview-method"
    #    "auto"
    #  ];
    #})

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
    #xwaylandvideobridge
    ssh-tools

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
    ffmpeg-full
    mkvtoolnix-cli
    vulkan-tools
    libva-utils
    wofi
    libqalculate
    #sunshine 
    moonlight-qt
    xfce.thunar
    wayland-scanner
    waypipe

    # Media
    plex-desktop
    jellyfin-media-player
    
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

    # Latex
    pkgs-old.texliveFull
    pkgs-old.texlive.combined.scheme-full
    latexRes-package

    # Terminals.
    kitty
    foot

    # Emulation
    wine
    wine64
    qemu

    # Mac Sound.
    libspatialaudio
    pulseaudio
    #t2AppleAudioDSP

    # Mac Camera.
    libcamera
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
      X11DisplayOffset = 10;
      X11UseLocalhost = true;
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
