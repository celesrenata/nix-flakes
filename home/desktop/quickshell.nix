# Quickshell desktop shell configuration
{ inputs, lib, pkgs, ... }:

{
  # Add environment variables to quickshell service.
  # NOTE: LD_LIBRARY_PATH for the quickshell venv libs is now set
  # service-scoped (without glibc) inside the dots-hyprland quickshell-service
  # module itself. It must NOT be re-added here with glibc: a glibc entry on
  # LD_LIBRARY_PATH forces binaries onto a pinned glibc and breaks the whole
  # session with "GLIBC_x.y not found" once that glibc drifts from the system.
  systemd.user.services.quickshell = {
    Service = {
      Environment = [
        "ILLOGICAL_IMPULSE_VIRTUAL_ENV=%h/.local/state/quickshell/.venv"
      ];
      ProtectSystem = lib.mkForce "false";  # Allow filesystem writes for color generation
    };
  };

  # Applied after legacy drop-ins and the upstream unit's environment entries.
  home.file.".config/systemd/user/quickshell.service.d/zz-local.conf".text = ''
    [Service]
    Environment="QML_IMPORT_PATH=${pkgs.kdePackages.kirigami.unwrapped}/lib/qt-6/qml:${pkgs.kdePackages.syntax-highlighting}/lib/qt-6/qml"
    Environment="QT_LOGGING_RULES=*.debug=false;quickshell.*.debug=false"
  '';

  # Ensure dots-hyprland setup marker exists so quickshell-startup skips its broken setup check
  home.activation.ensureDotsSetupMarker = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p $HOME/.cache/dots-hyprland
    test -f $HOME/.cache/dots-hyprland/setup-complete || echo "$(date)" > $HOME/.cache/dots-hyprland/setup-complete
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
