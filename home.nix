{ inputs, pkgs, pkgs-old, pkgs-unstable, ... }: 
let
  celes-dots = pkgs.fetchFromGitHub {
    owner = "celesrenata";
    repo = "dotfiles";
    rev = "a24961dd618ca10cfa50851aedff2a7e1affdeb0";
    sha256 = "sha256-QQVeINXRjRmU9eOX1OUTzHu0amz4ZFCJK8n8jYo+YPM=";
  };
  wofi-calc = pkgs.fetchFromGitHub {
    owner = "Zeioth";
    repo = "wofi-calc";
    rev = "edd316f3f40a6fcb2afadf5b6d9b14cc75a901e0";
    sha256 = "sha256-y8GoTHm0zPkeXhYS/enNAIrU+RhrUMnQ41MdHWWTPas=";
  };
  winapps = pkgs.fetchFromGitHub {
    owner = "celesrenata";
    repo = "winapps";
    rev = "0319c70fa0dec2da241e9a4b4e35a164f99d6307";
    sha256 = "sha256-+ZAtEDrHuLJBzF+R6guD7jYltoQcs88qEMvvpjiAXqI=";
  };

  in
  {
  imports = [ inputs.ags.homeManagerModules.default
              # inputs.toshy.homeManagerModules.toshy
              inputs.dots-hyprland.homeManagerModules.default
            ];

  programs.ags = {
    enable = false;  # Disabled in favor of dots-hyprland
    configDir = null;
    extraPackages = with pkgs; [
      gtksourceview
      gnome.gvfs
      webkitgtk
      accountsservice
    ];
  };

  # dots-hyprland configuration - NEW RICH CONFIGURATION SYSTEM! 🎉
  programs.dots-hyprland = {
    enable = true;
    source = inputs.dots-hyprland.packages.${pkgs.system}.configs or inputs.dots-hyprland;
    packageSet = "essential";
    mode = "declarative";
    
    # 🎨 Quickshell Configuration
    quickshell = {
      appearance = {
        extraBackgroundTint = true;
        fakeScreenRounding = 2;  # When not fullscreen
        transparency = false;    # Disable for performance
      };
      
      bar = {
        bottom = false;          # Top bar
        cornerStyle = 0;         # Hug style
        topLeftIcon = "spark";   # or "distro"
        showBackground = true;
        verbose = true;
        
        utilButtons = {
          showScreenSnip = true;
          showColorPicker = true;        # 🎯 Enable color picker!
          showMicToggle = true;          # Useful for meetings
          showKeyboardToggle = true;
          showDarkModeToggle = true;
          showPerformanceProfileToggle = false;
        };
        
        workspaces = {
          monochromeIcons = true;
          shown = 10;                    # Show 10 workspaces
          showAppIcons = true;
          alwaysShowNumbers = false;
          showNumberDelay = 300;
        };
      };
      
      battery = {
        low = 20;                        # Low battery threshold
        critical = 5;                    # Critical threshold
        automaticSuspend = true;
        suspend = 3;                     # Minutes before suspend
      };
      
      apps = {
        terminal = "foot";               # Use foot terminal
        bluetooth = "kcmshell6 kcm_bluetooth";
        network = "plasmawindowed org.kde.plasma.networkmanagement";
        taskManager = "plasma-systemmonitor --page-name Processes";
      };
      
      time = {
        format = "hh:mm";                # 12-hour format
        dateFormat = "ddd, dd/MM";       # Day, date/month
      };
    };
    
    # 🖥️ Hyprland Configuration
    hyprland = {
      general = {
        gapsIn = 4;                      # Inner gaps
        gapsOut = 7;                     # Outer gaps
        borderSize = 2;                  # Border width
        allowTearing = false;            # Disable tearing
      };
      
      decoration = {
        rounding = 16;                   # Corner rounding
        blurEnabled = true;              # Enable blur effects
      };
      
      gestures = {
        workspaceSwipe = true;           # Enable touchpad gestures
      };
      
      monitors = [
        # Add your monitor configuration here, e.g.:
        # "eDP-1,1920x1080@60,0x0,1"
        # "HDMI-A-1,1920x1080@60,1920x0,1"
      ];
    };
    
    # 🖥️ Terminal Configuration
    terminal = {
      scrollback = {
        lines = 1000;                    # Scrollback buffer
        multiplier = 3.0;
      };
      
      cursor = {
        style = "beam";                  # Beam cursor
        blink = false;
        beamThickness = 1.5;
      };
      
      colors = {
        alpha = 0.95;                    # Slight transparency
      };
      
      mouse = {
        hideWhenTyping = false;
        alternateScrollMode = true;
      };
    };
  };

  # TODO please change the username & home directory to your own
  home.username = "celes";
  home.homeDirectory = "/home/celes";
  #home.file.".configstaging/toshy/toshy_config.py" = {
  #  source = "${pkgs.toshy}/toshy_config.py";
  #};
  #home.file.".configstaging/toshy/toshy_user_preferences.sqlite" = {
  # source = "${pkgs.toshy}/toshy_user_preferences.sqlite";
  #};
  home.file."Backgrounds" = {
    source = celes-dots + "/Backgrounds";
    recursive = true;
  }; 
  home.file."winapps/pkg" = {
    source = winapps;
    recursive = true;
    executable = true;
  };
  home.file."winapps/runmefirst.sh" = {
    source = winapps + "/runmefirst.sh";
  };
  home.file.".local/bin/initialSetup.sh" = {
    source = celes-dots + "/.local/bin/initialSetup.sh";
  };
  home.file.".local/bin/sunshine" = {
    source = celes-dots + "/.local/bin/sunshineFixed";
  };
  home.file.".local/bin/agsAction.sh" = {
    source = celes-dots + "/.local/bin/agsAction.sh";
  };
  home.file.".local/bin/regexEscape.sh" = {
    source = celes-dots + "/.local/bin/regexEscape.sh";
  };
  #home.file.".local/bin/toshy-services-disable" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-services-disable.sh";
  #};
  #home.file.".local/bin/toshy-services-enable" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-services-enable.sh";
  #};
  #home.file.".local/bin/toshy-services-restart" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-services-restart.sh";
  #};
  #home.file.".local/bin/toshy-services-stop" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-services-stop.sh";
  #};
  #home.file.".local/bin/toshy-services-log" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-services-log.sh";
  #};
  #home.file.".local/bin/toshy-services-status" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-services-status.sh";
  #};
  #home.file.".local/bin/toshy-config-start" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-config-start.sh";
  #};
  #home.file.".local/bin/toshy-config-start-verbose" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-config-start-verbose.sh";
  #};
  #home.file.".local/bin/toshy-config-stop" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-config-stop.sh";
  #};
  #home.file.".local/bin/toshy-config-restart" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-config-restart.sh";
  #};
  #home.file.".local/bin/toshy-cosmic-dbus-service" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-cosmic-dbus-service.sh";
  #};
  #home.file.".local/bin/toshy-devices" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-devices.sh";
  #};
  #home.file.".local/bin/toshy-env" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-env.sh";
  #};
  #home.file.".local/bin/toshy-fnmode" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-fnmode.sh";
  #};
  #home.file.".local/bin/toshy-gui" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-gui.sh";
  #};
  #home.file.".local/bin/toshy-machine-id" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-machine-id.sh";
  #};
  #home.file.".local/bin/toshy-kde-dbus-service" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-kde-dbus-service.sh";
  #};
  #home.file.".local/bin/toshy-systemd-remove" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-systemd-remove.sh";
  #};
  #home.file.".local/bin/toshy-systemd-setup" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-systemd-setup.sh";
  #};
  #home.file.".local/bin/toshy-tray" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-tray.sh";
  #};
  #home.file.".local/bin/toshy-versions" = {
  #  source = "${pkgs.toshy}/scripts/bin/toshy-versions.sh";
  #};
  home.file.".local/bin/wofi-calc" = {
    source = wofi-calc + "/wofi-calc.sh";
  };
  # home.file.".config/hypr/hyprland.conf" = {
  #   source = pkgs.end-4-dots + "/hypr/hyprland.conf.bak";
  # };  # Commented out - now managed by dots-hyprland
  #home.file.".config/toshy/toshy_gui.py" = {
  #  source = "${pkgs.toshy}/toshy_gui.py";
  #};
  #home.file.".config/toshy/toshy_tray.py" = {
  #  source = "${pkgs.toshy}/toshy_tray.py";
  #};
  #home.file.".local/share/icons/toshy_app_icon_rainbow.svg" = {
  #  source = "${pkgs.toshy}/assets/toshy_app_icon_rainbow.svg";
  #};
  #home.file.".local/share/icons/toshy_app_icon_inverse.svg" = {
  #  source = "${pkgs.toshy}/assets/toshy_app_icon_inverse.svg";
  #};
  #home.file.".local/share/icons/toshy_app_icon_grayscale.svg" = {
  #  source = "${pkgs.toshy}/assets/toshy_app_icon_grayscale.svg";
  #};
  #home.file.".config/toshy/assets" = {
  #  source = "${pkgs.toshy}/assets";
  #  recursive = true;
  #};
  #home.file.".config/toshy/lib" = {
  #  source = "${pkgs.toshy}/lib";
  #  recursive = true;
  #};
  #home.file.".config/toshy/kde-kwin-dbus-service" = {
  #  source = "${pkgs.toshy}/kde-kwin-dbus-service";
  #  recursive = true;
  #};
  # set cursor size and dpi for 4k monitor
  xresources.properties = {
    "Xcursor.size" = 24;
    "Xft.dpi" = 172;
  };
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # Modular Programs
  # VSCode
  programs.vscode = {
    enable = true;
    package = pkgs-unstable.vscode;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      #dracula-theme.theme-dracula
      #vscodevim.vim
      #yzhang.markdown-all-in-one
      #ms-python.python
      oderwat.indent-rainbow
      eamodio.gitlens
      jnoortheen.nix-ide
    ];
  };
  programs.btop.settings = {
    package = pkgs-unstable.btop;
    color_theme = "Default";
    theme_background = false;
  };

  # Obs.
  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      #pkgs.obs-backgroundremovalOverride
      #obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-vaapi
      wlrobs
      obs-vintage-filter
    ];
  };

  # Packages that should be installed to the user profile.
  home.packages = 
  (with pkgs-old; [
    gnome.gvfs 
  ])

  ++

  (with pkgs; [
    # here is some command line tools I use frequently
    # feel free to add your own or remove some of them

    nnn # terminal file manager

    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder

    # programs
    firefox
    chromium
    spotify
    discord
    darktable
    signal-desktop
    kdePackages.dolphin

    # Extra Launchers.

    # networking tools
    mtr # A network diagnostic tool
    iperf3
    dnsutils  # `dig` + `nslookup`
    ldns # replacement of `dig`, it provide the command `drill`
    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing
    ipcalc  # it is a calculator for the IPv4/v6 addresses
    nmap

    # Graphical Editing.
    gimp
    darktable
    blender

    # misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    # Gaming.
    antimicrox

    # nix related
    #
    # it provides the command `nom` works just like `nix`
    # with more details log output
    nix-output-monitor

    # productivity
    hugo # static site generator
    glow # markdown previewer in terminal

    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
    wofi-calc
    imagemagick
    openrgb-with-all-plugins
    KeyboardVisualizer
    wlvncc
    tigervnc

    # Development
    nodePackages.aws-cdk
    awscli2
    # MicroTex Deps
    tinyxml-2
    gtkmm3
    gtksourceviewmm
    cairomm
    gnumake

    # Other
    graphviz

    # Python - Your custom environment (lower priority than dots-hyprland)
    pyenv.out
    (pkgs.lib.setPrio 10 (python312.withPackages(ps: with ps; [
      # Your specific packages
      evdev           # For input handling
      xkeysnail       # For key remapping
      pydbus          # For D-Bus communication
      dbus-python     # For D-Bus communication
      watchdog        # For file watching
      pandas          # For data analysis
      gtk3            # For GTK apps
      pygobject3      # For GObject introspection
      matplotlib      # For plotting
      poetry-core     # For poetry
      pywal           # For color schemes
      pip             # Package installer
      setuptools-scm  # For setuptools
      wheel           # For wheel packages
      appdirs         # For app directories
      inotify-simple  # For file monitoring
      ordered-set     # For ordered sets
      six             # Python 2/3 compatibility
      hatchling       # For hatch builds
      pycairo         # For Cairo graphics
    ])))

    # Player and Audio
    pavucontrol
    wireplumber
    libdbusmenu-gtk3
    #plasma-browser-integration
    playerctl
    swww
    mpv
    vlc

    # GTK
    webp-pixbuf-loader
    gtk-layer-shell
    gtk3
    gtksourceview3
    upower
    yad
    ydotool
    gobject-introspection
    wrapGAppsHook

    # QT
    libsForQt5.qwt

    # Gnome Stuff
    polkit_gnome
    gnome-keyring
    gnome-control-center
    gnome-bluetooth
    gnome-shell
    nautilus
    nodejs_20
    yaru-theme
    blueberry
    networkmanager
    brightnessctl
    wlsunset
    gjs
    gjs.dev

    # AGS and Hyprland dependencies.
    coreutils
    cliphist
    curl
    ddcutil
    fuzzel
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

    # Shells and Terminals
    starship
    foot

    # Themes
    adw-gtk3
    libsForQt5.qt5ct
    gradience

    # Screenshot and Recorder
    swappy
    wf-recorder
    grim
    tesseract
    slurp 
  ])

  ++

  (with pkgs-unstable; [
    fastfetch
    #sunshine
    tidal-hifi
    # hypridle  # Now provided by dots-hyprland
    # hyprlock  # Now provided by dots-hyprland
    lan-mouse
    #python311Packages.debugpy
    vesktop
    #(python311.withPackages(ps: with ps; [
      # Ollama.
      #torchvision
      #torchaudio
      #torch
      #diffusers
      #transformers
      #accelerate
     #]))
  ]);

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  # starship - an customizable prompt for any shell
  programs.starship = {
    enable = true;
    # custom settings
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  # alacritty - a cross-platform, GPU-accelerated terminal emulator
  programs.alacritty = {
    enable = true;
    # custom settings
    settings = {
      env.TERM = "xterm-256color";
      font = {
        size = 12;
        draw_bold_text_with_bright_colors = true;
      };
      scrolling.multiplier = 5;
      selection.save_to_clipboard = true;
    };
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
    # TODO add your custom bashrc here
    bashrcExtra = ''
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin:"
    '';

    # set some aliases, feel free to add more or remove some
    shellAliases = {
      k = "kubectl";
      urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
      urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
    };
    sessionVariables = {
      EDITOR = "vim";
    };
  };
  
  home.sessionVariables = {
    LD_LIBRARY_PATH = pkgs.lib.mkDefault "/run/opengl-driver/lib";
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
