# Development tools and programming environment
{ inputs, lib, pkgs, ... }:

{
  # VSCode configuration
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
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
    nil

    # AWS Tools
    aws-cdk-cli
    awscli2

    # MicroTex Dependencies
    tinyxml-2
    gtkmm3
    gtksourceviewmm
    cairomm
    gnumake

    # Other development tools
    graphviz
    inputs.mermaid-rs-renderer.packages.${pkgs.stdenv.hostPlatform.system}.default  # mmdr - fast mermaid renderer

    # Python environment with development packages
    pyenv.out
    (pkgs.lib.setPrio 10 (python313.withPackages(ps: with ps; [
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
