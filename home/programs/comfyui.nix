{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    comfyui
  ];

  systemd.user.services.comfyui = {
    Unit = {
      Description = "ComfyUI Server";
      After = [ "network.target" ];
    };
    Service = {
      ExecStart = "${pkgs.comfyui}/bin/comfyui --listen 0.0.0.0 --port 8188";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
