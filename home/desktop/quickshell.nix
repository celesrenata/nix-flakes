# Quickshell desktop shell configuration
{ inputs, lib, pkgs, pkgs-unstable, ... }:

{
  # Add environment variables to quickshell service
  systemd.user.services.quickshell = {
    Service = {
      Environment = [
        "LD_LIBRARY_PATH=${lib.makeLibraryPath [
          pkgs.gcc.cc.lib
          pkgs.glibc
          pkgs.zlib
          pkgs.libffi
          pkgs.openssl
          pkgs.bzip2
          pkgs.xz
          pkgs.ncurses
          pkgs.readline
          pkgs.sqlite
        ]}"
        "ILLOGICAL_IMPULSE_VIRTUAL_ENV=%h/.local/state/quickshell/.venv"
      ];
      ProtectSystem = lib.mkForce "false";  # Allow filesystem writes for color generation
    };
  };

  # Generate env.sh and deploy quickshell fixes
  home.activation.generateQuickshellEnv = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.config/quickshell
    cat > $HOME/.config/quickshell/env.sh << 'EOF'
export LD_LIBRARY_PATH="${lib.makeLibraryPath [
  pkgs.gcc.cc.lib
  pkgs.glibc
  pkgs.zlib
  pkgs.libffi
  pkgs.openssl
  pkgs.bzip2
  pkgs.xz
  pkgs.ncurses
  pkgs.readline
  pkgs.sqlite
]}"
EOF
    
    # Deploy quickshell scripts and fixes if quickshell config exists
    if [ -d "$HOME/.config/quickshell/ii" ]; then
      echo "Deploying quickshell scripts..."
      
      # Copy color scripts
      mkdir -p $HOME/.config/quickshell/ii/scripts/colors
      cp ${./quickshell-scripts}/*.sh $HOME/.config/quickshell/ii/scripts/colors/
      cp ${./quickshell-scripts}/*.py $HOME/.config/quickshell/ii/scripts/colors/
      chmod +x $HOME/.config/quickshell/ii/scripts/colors/*.sh
      chmod +x $HOME/.config/quickshell/ii/scripts/colors/*.py
      
      # Copy terminal sequences
      mkdir -p $HOME/.config/quickshell/ii/scripts/colors/terminal
      cp -r ${./quickshell-scripts/terminal}/* $HOME/.config/quickshell/ii/scripts/colors/terminal/
      
      # Copy MaterialThemeLoader
      cp ${./quickshell-scripts}/MaterialThemeLoader.qml $HOME/.config/quickshell/ii/services/
      
      # Update Directories.qml to use switchwall-wrapper.sh
      if [ -f "$HOME/.config/quickshell/ii/modules/common/Directories.qml" ]; then
        ${pkgs.gnused}/bin/sed -i 's|switchwall\.sh|switchwall-wrapper.sh|g' \
          $HOME/.config/quickshell/ii/modules/common/Directories.qml
      fi
    fi
  '';

  # Temporarily disabled due to build issues with Qt6::WaylandClientPrivate
  # 🎨 Quickshell Configuration (still using rich config)
  # programs.dots-hyprland.quickshell = {
  #   appearance = {
  #     extraBackgroundTint = true;
  #     fakeScreenRounding = 2;  # When not fullscreen
  #     transparency = false;    # Disable for performance
  #   };
  #   
  #   bar = {
  #     bottom = false;          # Top bar
  #     cornerStyle = 0;         # Hug style
  #     topLeftIcon = "spark";   # or "distro"
  #     showBackground = true;
  #     verbose = true;
  #     
  #     utilButtons = {
  #       showScreenSnip = true;
  #       showColorPicker = true;        # 🎯 Enable color picker!
  #       showMicToggle = true;          # Useful for meetings
  #       showKeyboardToggle = true;
  #       showDarkModeToggle = true;
  #       showPerformanceProfileToggle = false;
  #     };
  #     
  #     workspaces = {
  #       monochromeIcons = true;
  #       shown = 10;                    # Show 10 workspaces
  #       showAppIcons = true;
  #       alwaysShowNumbers = false;
  #       showNumberDelay = 300;
  #     };
  #   };
  #   
  #   battery = {
  #     low = 20;                        # Low battery threshold
  #     critical = 5;                    # Critical threshold
  #     automaticSuspend = true;
  #     suspend = 3;                     # Minutes before suspend
  #   };
  #   
  #   apps = {
  #     terminal = "foot";               # Use foot terminal
  #     bluetooth = "kcmshell6 kcm_bluetooth";
  #     network = "plasmawindowed org.kde.plasma.networkmanagement";
  #     taskManager = "plasma-systemmonitor --page-name Processes";
  #   };
  #   
  #   time = {
  #     format = "hh:mm";                # 12-hour format
  #     dateFormat = "ddd, dd/MM";       # Day, date/month
  #   };
  # };
  
  # 🖥️ Hyprland Configuration
  programs.dots-hyprland.hyprland = {
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
}
