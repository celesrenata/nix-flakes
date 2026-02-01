# Hyte Touch Display User Service
{ inputs, lib, pkgs, pkgs-old, pkgs-unstable, config, ... }:

{
  # Sops secret for Grafana API token
  sops.secrets.grafana_api_token = {
    sopsFile = ../../secrets/secrets.yaml;
  };

  # Install Qt WebEngine for embedded browser
  home.packages = with pkgs; [
    qt6.qtwebengine
  ];

  # Direct QuickShell on DP-3
  systemd.user.services.hyte-touch-display = {
    Unit = {
      Description = "Hyte Touch Display QuickShell";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "quickshell-wrapper" ''
        export WAYLAND_DISPLAY=wayland-1
        export QML2_IMPORT_PATH=${pkgs.qt6.qtwebengine}/lib/qt-6/qml
        export QTWEBENGINE_DISABLE_SANDBOX=1
        export QTWEBENGINE_CHROMIUM_FLAGS="--no-sandbox --disable-gpu"
        export GRAFANA_API_TOKEN=$(cat ${config.sops.secrets.grafana_api_token.path})
        exec ${pkgs.quickshell}/bin/quickshell -p /home/celes/.config/quickshell/touch "$@"
      ''}";
      Restart = "always";
      RestartSec = "3s";
    };
    
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
