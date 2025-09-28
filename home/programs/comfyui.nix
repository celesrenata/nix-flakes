{ config, pkgs, inputs, ... }:

let
  comfyui = pkgs.comfyui;
  
  comfyui-wrapper = pkgs.writeShellScript "comfyui-wrapper" ''
    export NIXPKGS_ALLOW_UNFREE=1
    exec ${pkgs.nix}/bin/nix-shell --impure -p uv git python3 libGL libGLU stdenv.cc.cc.lib fontconfig dejavu_fonts --run "
      export PATH=\$PATH
      export VIRTUAL_ENV=${config.home.homeDirectory}/.config/comfy-ui/venv
      export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.glib.out}/lib:/run/opengl-driver/lib:\$LD_LIBRARY_PATH
      cd ${config.home.homeDirectory}/.config/comfy-ui/app
      exec ${config.home.homeDirectory}/.config/comfy-ui/venv/bin/python main.py --base-dir ${config.home.homeDirectory}/.config/comfy-ui --listen 0.0.0.0 \$*
    "
  '';
in
{
  home.packages = [ comfyui ];

  systemd.user.services.comfyui = {
    Unit = {
      Description = "ComfyUI Server";
      After = [ "network.target" ];
    };
    Service = {
      Type = "exec";
      ExecStart = "${comfyui-wrapper} --listen 0.0.0.0 --port 8188";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "COMFY_VERSION=latest"
        "COMFY_HOME=${config.home.homeDirectory}/.config/comfy-ui"
        "BASE_DIR=${config.home.homeDirectory}/.config/comfy-ui"
        "COMFY_MODELS_DIR=${config.home.homeDirectory}/.config/comfy-ui/models"
        "COMFY_OUTPUT_DIR=${config.home.homeDirectory}/.config/comfy-ui/output"
        "COMFY_INPUT_DIR=${config.home.homeDirectory}/.config/comfy-ui/input"
        "COMFY_TEMP_DIR=${config.home.homeDirectory}/.config/comfy-ui/temp"
        "COMFYUI_SRC=${config.home.homeDirectory}/.config/comfy-ui/ComfyUI"
        "PYTHONPATH=${config.home.homeDirectory}/.config/comfy-ui"
        "COMFYUI_MANAGER_SECURITY_LEVEL=weak"
        "VIRTUAL_ENV=${config.home.homeDirectory}/.config/comfy-ui/venv"
        "PATH=${config.home.homeDirectory}/.config/comfy-ui/venv/bin:${pkgs.uv}/bin:/run/current-system/sw/bin"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
