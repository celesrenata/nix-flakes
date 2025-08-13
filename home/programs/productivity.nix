# Productivity applications and office tools
{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, ... }:

{
  # System monitoring
  programs.btop.settings = {
    package = pkgs-unstable.btop;
    color_theme = "Default";
    theme_background = false;
  };

  # Productivity packages
  home.packages = with pkgs; [
    # Web browsers
    firefox
    chromium
    
    # File managers
    kdePackages.dolphin
    nnn  # terminal file manager
    
    # Office and productivity
    hugo  # static site generator
    glow  # markdown previewer in terminal
    
    # System utilities
    btop
    iotop  # io monitoring
    iftop  # network monitoring
    
    # System monitoring and debugging
    strace  # system call monitoring
    ltrace  # library call monitoring
    lsof    # list open files
    sysstat
    lm_sensors  # for `sensors` command
    ethtool
    pciutils  # lspci
    usbutils  # lsusb
    
    # Calculator
    wofi-calc
    
    # Hardware control
    openrgb-with-all-plugins
    KeyboardVisualizer
    
    # Remote access
    wlvncc
    tigervnc
    
    # Archive utilities
    zip
    xz
    unzip
    p7zip
    
    # Command line utilities
    ripgrep  # recursively searches directories for a regex pattern
    jq       # A lightweight and flexible command-line JSON processor
    yq-go    # yaml processer
    eza      # A modern replacement for 'ls'
    fzf      # A command-line fuzzy finder
    
    # Networking tools
    mtr      # A network diagnostic tool
    iperf3
    dnsutils # `dig` + `nslookup`
    ldns     # replacement of `dig`, provides `drill`
    aria2    # multi-protocol download utility
    socat    # replacement of openbsd-netcat
    nmap     # network discovery and security auditing
    ipcalc   # IPv4/v6 address calculator
    
    # Misc utilities
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg
    
    # Nix related tools
    nix-output-monitor  # provides `nom` command with detailed logs
  ] ++ (with pkgs-old; [
    # Packages from older nixpkgs
    gnome.gvfs
  ]);
}
