{ inputs, pkgs, ... }:
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
  in
  {
  imports = [ inputs.ags.homeManagerModules.default ];

  programs.ags = {
    enable = true;
    configDir = null;
    extraPackages = with pkgs; [
      gtksourceview
      webkitgtk
      accountsservice
    ];
  };

  # TODO please change the username & home directory to your own
  home.username = "celes";
  home.homeDirectory = "/home/celes";

  # link the configuration file in current directory to the specified location in home directory
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # link all files in `./scripts` to `~/.config/i3/scripts`

  home.file.".configstaging" = {
    source = pkgs.end-4-dots;
    recursive = true;   # link recursively
    executable = true;  # make all files executable
  };
  home.file.".configstaging/toshy/toshy_config.py" = {
    source = "${pkgs.toshy}/toshy_config.py";
  };
  home.file.".configstaging/toshy/toshy_user_preferences.sqlite" = {
   source = "${pkgs.toshy}/toshy_user_preferences.sqlite";
  };
  home.file."Backgrounds" = {
    source = celes-dots + "/Backgrounds";
    recursive = true;
  };
  home.file.".local/bin/initialSetup.sh" = {
    source = pkgs.end-4-dots + "/.local/bin/initialSetup.sh";
  };
  home.file.".local/bin/agsAction.sh" = {
    source = celes-dots + "/.local/bin/agsAction.sh";
  };
  home.file.".local/bin/regexEscape.sh" = {
    source = celes-dots + "/.local/bin/regexEscape.sh";
  };
  home.file.".local/bin/toshy-services-disable" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-services-disable.sh";
  };
  home.file.".local/bin/toshy-services-enable" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-services-enable.sh";
  };
  home.file.".local/bin/toshy-services-restart" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-services-restart.sh";
  };
  home.file.".local/bin/toshy-services-stop" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-services-stop.sh";
  };
  home.file.".local/bin/toshy-services-log" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-services-log.sh";
  };
  home.file.".local/bin/toshy-services-status" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-services-status.sh";
  };
  home.file.".local/bin/toshy-config-start" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-config-start.sh";
  };
  home.file.".local/bin/toshy-config-start-verbose" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-config-start-verbose.sh";
  };
  home.file.".local/bin/toshy-config-stop" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-config-stop.sh";
  };
  home.file.".local/bin/toshy-config-restart" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-config-restart.sh";
  };
  home.file.".local/bin/toshy-cosmic-dbus-service" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-cosmic-dbus-service.sh";
  };
  home.file.".local/bin/toshy-devices" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-devices.sh";
  };
  home.file.".local/bin/toshy-env" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-env.sh";
  };
  home.file.".local/bin/toshy-fnmode" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-fnmode.sh";
  };
  home.file.".local/bin/toshy-gui" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-gui.sh";
  };
  home.file.".local/bin/toshy-machine-id" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-machine-id.sh";
  };
  home.file.".local/bin/toshy-kde-dbus-service" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-kde-dbus-service.sh";
  };
  home.file.".local/bin/toshy-systemd-remove" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-systemd-remove.sh";
  };
  home.file.".local/bin/toshy-systemd-setup" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-systemd-setup.sh";
  };
  home.file.".local/bin/toshy-tray" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-tray.sh";
  };
  home.file.".local/bin/toshy-versions" = {
    source = "${pkgs.toshy}/scripts/bin/toshy-versions.sh";
  };
  home.file.".local/bin/wofi-calc" = {
    source = wofi-calc + "/wofi-calc.sh";
  };
  home.file.".config/hypr/hyprland.conf" = {
    source = pkgs.end-4-dots + "/hypr/hyprland.conf.bak";
  };
  home.file.".config/toshy/toshy_gui.py" = {
    source = "${pkgs.toshy}/toshy_gui.py";
  };
  home.file.".config/toshy/toshy_tray.py" = {
    source = "${pkgs.toshy}/toshy_tray.py";
  };
  home.file.".local/share/icons/toshy_app_icon_rainbow.svg" = {
    source = "${pkgs.toshy}/assets/toshy_app_icon_rainbow.svg";
  };
  home.file.".local/share/icons/toshy_app_icon_inverse.svg" = {
    source = "${pkgs.toshy}/assets/toshy_app_icon_inverse.svg";
  };
  home.file.".local/share/icons/toshy_app_icon_grayscale.svg" = {
    source = "${pkgs.toshy}/assets/toshy_app_icon_grayscale.svg";
  };
  home.file.".config/toshy/assets" = {
    source = "${pkgs.toshy}/assets";
    recursive = true;
  };
  home.file.".config/toshy/lib" = {
    source = "${pkgs.toshy}/lib";
    recursive = true;
  };
  home.file.".config/toshy/kde-kwin-dbus-service" = {
    source = "${pkgs.toshy}/kde-kwin-dbus-service";
    recursive = true;
  };
  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # set cursor size and dpi for 4k monitor
  #xresources.properties = {
  #  "Xcursor.size" = 24;
  #  "Xft.dpi" = 172;
  #};
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
    package = pkgs.vscode;
    extensions = with pkgs.vscode-extensions; [
      dracula-theme.theme-dracula
      #vscodevim.vim
      #yzhang.markdown-all-in-one
      #ms-python.python
      oderwat.indent-rainbow
      #eamodio.gitlens
      jnoortheen.nix-ide
    ];
  };

  # Packages that should be installed to the user profile.
  home.packages = 
  (with pkgs; [
    # here is some command line tools I use frequently
    # feel free to add your own or remove some of them
    fastfetch
    macchina
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
    fzf # A command-line fuzzy finder

    # programs
    firefox
    chromium

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
    tigervnc

    # Graphical Editing.
    gimp
    darktable

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
    lsof # list open files

    # system tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
    wofi-calc
    remmina
    rdesktop
    freerdp

    # Development
    # MicroTex Deps
    tinyxml-2
    gtkmm3
    gtksourceviewmm
    cairomm

    # Other
    graphviz

    # Player and Audio
    pavucontrol
    libdbusmenu-gtk3
    plasma-browser-integration
    playerctl
    mpv
    vlc

    # GTK
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
    gnome-network-displaysOverride
    yaru-theme
    blueberry
    networkmanager
    brightnessctl
    wlsunset

    # AGS and Hyprland dependencies.
    coreutils
    cliphist
    curl
    fuzzel
    ripgrep
    gjs
    axel
    wlogout
    wl-clipboard
    gammastep
    libnotify

    # Themes
    libsForQt5.qt5ct

    # Screenshot and Recorder
    swappy
    wf-recorder
    grim
    tesseract
    slurp 
#  ])
#
#  ++
#
#    (with pkgs-unstable; [
    adw-gtk3
    legcord
    dart-sass
    eza
    gojq
    gradience
    hypridle
    hyprlock
    hyprpicker
    lan-mouse
    # Python
    pyenv.out
    (python312.withPackages(ps: with ps; [
      materialyoucolor
      material-color-utilities
      pillow
      poetry-core
      pywal
      setuptools-scm
      wheel
      pywayland
      psutil
      pydbus
      dbus-python
      python-xwaykeyz
      pygobject3
      watchdog
      pip
      evdev
      appdirs
      inotify-simple
      ordered-set
      six
      hatchling
      pycairo
      xkeysnail
    ]))
    python312Packages.debugpy
    swww
    webp-pixbuf-loader
    wireplumber
  ]);

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    userName = "Celes Renata";
    userEmail = "celes@celestium.life";
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
  
  home.sessionPath = [
    ".local/bin"
  ];
  home.sessionVariables = {
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
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
