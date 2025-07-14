{ pkgs, ... }:
{
  systemd.user.services.toshy-config = {
    enable = true;
    after = [ "network.target" ];
    wantedBy = [ "default.target" ];
    description = "Toshy Config Service";
    #environment = {
    #  XDG_RUNTIME_DIR = "/run/user/1000";
    #};
    path = with pkgs; [ 
      bash
      coreutils
      libnotify
      procps
      toshy
      zenity
      (python312.withPackages(ps: with ps; [
        appdirs
        dbus-python
        evdev
        hatchling
        inotify-simple
        ordered-set
        pydantic
        pydbus
        python-hyprpy
        python-i3ipc
        python-xlib
        python-xwaykeyz
        pywayland
        six
        watchdog
      ]))
    ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre="${pkgs.bash}/bin/bash -c 'env TERM=xterm ${pkgs.toshy}/scripts/toshy-service-config-execstartpre.sh'";
      ExecStart="${pkgs.bash}/bin/bash -c 'env TERM=xterm ${pkgs.toshy}/scripts/toshy-service-config.sh'";
      Restart="always";
      RestartSec=5;
    };
  };
  systemd.user.services.toshy-session-monitor = {
    enable = true;
    after = [ "default.target" ];
    wantedBy = [ "default.target" ];
    description = "Toshy Session Monitor";
    path = [ pkgs.coreutils pkgs.bash ];
    serviceConfig = {
      Type = "simple";
      ExecStart="${pkgs.bash}/bin/bash -c 'env TERM=xterm ${pkgs.toshy}/scripts/toshy-service-session-monitor.sh'";
      Restart="always";
      RestartSec=5;
    };
  };
  systemd.user.services.toshy-kde-dbus = {
    enable = true;
    wantedBy = [ "default.target" ];
    description = "Toshy KDE D-Bus Service";
    path = [ pkgs.coreutils pkgs.bash ];
    unitConfig = {
      StartLimitBurst=5;
      StartLimitIntervalSec=60;
    };
    serviceConfig = {
      Type = "simple";
      ExecStartPre="${pkgs.bash}/bin/bash -c 'if [ -z \"$XDG_SESSION_TYPE\" ]; then sleep 3; exit 1; fi'";
      ExecStart="${pkgs.bash}/bin/bash -c 'env TERM=xterm ${pkgs.toshy}/scripts/bin/toshy-kde-dbus-service.sh'";
      Restart="on-failure";
      RestartSec=5;
    };
  };
}
