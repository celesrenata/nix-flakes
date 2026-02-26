# Development tools and programming environment
{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, ... }:

{
  # VSCode configuration
  programs.vscode = {
    enable = true;
    package = pkgs-unstable.vscode;
    profiles.default.extensions = with pkgs.vscode-extensions; [
      oderwat.indent-rainbow
      eamodio.gitlens
      jnoortheen.nix-ide
    ];
  };

  # Git configuration
  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  # Development packages
  home.packages = with pkgs; [
    # Development Tools
    amazon-q-cli
    jetbrains-toolbox
    git
    git-lfs
    nodejs_20
    meson
    # gcc13                                 # Temporarily disabled due to collision with clang
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
    node2nix
    nil

    # AWS Tools
    nodePackages.aws-cdk
    awscli2

    # MicroTex Dependencies
    tinyxml-2
    gtkmm3
    gtksourceviewmm
    cairomm
    gnumake

    # Other development tools
    graphviz

    # Python environment with development packages
    pyenv.out
    (pkgs.lib.setPrio 10 (python312.withPackages(ps: with ps; [
      # Input handling and system integration
      evdev
      xkeysnail
      pydbus
      dbus-python
      watchdog
      
      # Data analysis and visualization
      pandas
      matplotlib
      
      # GUI and desktop integration
      gtk3
      pygobject3
      
      # Package management and build tools
      poetry-core
      pip
      setuptools-scm
      wheel
      hatchling
      
      # Utilities
      pywal
      appdirs
      inotify-simple
      ordered-set
      six
      pycairo
    ])))
  ] ++ (with pkgs; [
    # Unstable development packages
    fastfetch
    vesktop
  ]);
}
