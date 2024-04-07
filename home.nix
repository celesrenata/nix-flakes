{ inputs, pkgs, ... }: 
let
  celes-dots = pkgs.fetchFromGitHub {
    owner = "celesrenata";
    repo = "dotfiles";
    rev = "bef0ee728a1531d357e69dbebd49cf424f103a03";
    sha256 = "sha256-pyBJZERwIiuMPMqjE8XTzzhGFRDA1C6xIlXomnylUB4=";
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

  home.file.".config" = {
    source = pkgs.end-4-dots;
    recursive = true;   # link recursively
    executable = true;  # make all files executable
  };
  home.file.".config/touchegg/touchegg.conf" = {
    source = celes-dots + "/.config/touchegg/touchegg.conf";
  };
  home.file.".config/ags/scripts/windowstate/state.sh" = {
    source = celes-dots + "/.config/ags/scripts/windowstate/state.sh";
  };
  home.file.".config/ags/scripts/templates/foot/foot.ini" = {
    source = celes-dots + "/.config/ags/scripts/templates/foot/foot.ini";
  };
  home.file.".config/ags/scripts/templates/wofi/style.css" = {
    source = celes-dots + "/.config/ags/scripts/templates/wofi/style.css";
  };
  home.file.".config/wofi/config" = {
    source = celes-dots + "/.config/wofi/config";
  };
  home.file.".local/bin/initialSetup.sh" = {
    source = celes-dots + "/.local/bin/initialSetup.sh";
  };
  home.file."Backgrounds/love-is-love.jpg" = {
    source = celes-dots + "/love-is-love.jpg";
  };

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  # set cursor size and dpi for 4k monitor
  xresources.properties = {
    "Xcursor.size" = 24;
    "Xft.dpi" = 172;
  };

  # Modular Programs
  # VSCode
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      #dracula-theme.theme-dracula
      #vscodevim.vim
      #yzhang.markdown-all-in-one
      ms-python.python
      oderwat.indent-rainbow
      eamodio.gitlens
      jnoortheen.nix-ide
    ];
  };

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    # here is some command line tools I use frequently
    # feel free to add your own or remove some of them

    neofetch
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
    eza # A modern replacement for ‘ls’
    fzf # A command-line fuzzy finder

    # programs
    firefox
    tidal-hifi
    discord

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

    btop  # replacement of htop/nmon
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
    toshy
    openrgb-with-all-plugins
    KeyboardVisualizer

    # Development
    # MicroTex Deps
    tinyxml-2
    gtkmm3
    gtksourceviewmm
    cairomm

    # Python
    pyenv.out
    (python311.withPackages(ps: with ps; [
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
      watchdog
      pip
      evdev
      appdirs
      inotify-simple
      ordered-set
      six
      hatchling
      python-xlib
      python-keyszer
      python-hyprpy
      pycairo
    ]))

    # Player and Audio
    pavucontrol
    wireplumber
    libdbusmenu-gtk3
    plasma-browser-integration
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

    # QT
    libsForQt5.qwt

    # Gnome Stuff
    polkit_gnome
    gnome.gnome-keyring
    gnome.gnome-control-center
    gnome.gnome-bluetooth
    gnome.gnome-shell
    gnome-pie
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
    gojq
    gjs
    dart-sass
    axel
    hypridle
    hyprlock
    wlogout
    wl-clipboard
    hyprpicker

    # Fonts
    fontconfig
    lexend
    nerdfonts
    material-symbols
    bibata-cursors

    # Shells and Terminals
    foot
    fish
    starship

    # Themes
    adw-gtk3
    qt5ct
    gradience

    # Screenshot and Recorder
    swappy
    wf-recorder
    grim
    tesseract
    slurp 
  ];

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
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"
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

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.05";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
