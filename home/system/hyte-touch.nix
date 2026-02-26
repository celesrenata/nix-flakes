# Hyte Touch Display User Service
{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, config, ... }:

let
  pythonWithAudio = pkgs.python312.withPackages (ps: with ps; [ numpy scipy ]);
in
{
  # Install Qt WebEngine for embedded browser
  home.packages = with pkgs; [
    qt6.qtwebengine
    projectm-sdl-cpp  # Standalone music visualizer
  ];

  # Deploy touch quickshell config
  home.file.".config/quickshell/touch" = {
    source = inputs.hyte-touch-infinite-flakes + "/config/quickshell";
    recursive = true;
  };

  # Direct QuickShell on DP-3
  systemd.user.services.hyte-touch-display = {
    Unit = {
      Description = "Hyte Touch Display QuickShell";
      After = [ "graphical-session.target" "projectm-visualizer.service" ];
      Requires = [ "projectm-visualizer.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    
    Service = {
      Type = "simple";
      Environment = "PATH=${pythonWithAudio}/bin:${pkgs.pulseaudio}/bin:/run/current-system/sw/bin";
      ExecStart = "${pkgs.writeShellScript "quickshell-wrapper" ''
        export WAYLAND_DISPLAY=wayland-1
        export QML2_IMPORT_PATH=${pkgs.qt6.qtwebengine}/lib/qt-6/qml
        export QTWEBENGINE_DISABLE_SANDBOX=1
        export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu"
        export GRAFANA_API_TOKEN=$(cat /run/secrets/grafana_api_token)
        exec ${pkgs.quickshell}/bin/quickshell -p /home/celes/.config/quickshell/touch "$@"
      ''}";
      Restart = "always";
      RestartSec = "3s";
    };
    
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
  
  # ProjectM visualizer running behind QuickShell
  systemd.user.services.projectm-visualizer = {
    Unit = {
      Description = "ProjectM Music Visualizer";
      After = [ "graphical-session.target" "hyprland-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "projectm-wrapper" ''
        export WAYLAND_DISPLAY=wayland-1
        export SDL_VIDEODRIVER=wayland
        exec ${pkgs.projectm-sdl-cpp}/bin/projectMSDL --fullscreen 1 --monitor 2
      ''}";
      Restart = "always";
      RestartSec = "3s";
    };
    
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
