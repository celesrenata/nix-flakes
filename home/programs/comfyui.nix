{ config, pkgs, inputs, ... }:

let
  comfyui = pkgs.comfyui;
  
  comfyui-wrapper = pkgs.writeShellScript "comfyui-wrapper" ''
    export NIXPKGS_ALLOW_UNFREE=1
    export VENV_DIR=${config.home.homeDirectory}/.config/comfy-ui/venv
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.glib.out}/lib:${pkgs.libGL}/lib:${pkgs.libGLU}/lib:${pkgs.glib}/lib:/run/opengl-driver/lib:$LD_LIBRARY_PATH
    
    # Copy ComfyUI source if it doesn't exist
    if [ ! -f ${config.home.homeDirectory}/.config/comfy-ui/app/main.py ]; then
      echo 'Copying ComfyUI source files...'
      mkdir -p ${config.home.homeDirectory}/.config/comfy-ui
      cp -r ${comfyui}/opt/comfyui ${config.home.homeDirectory}/.config/comfy-ui/app
    fi
    
    # Create required directory structure
    mkdir -p ${config.home.homeDirectory}/.config/comfy-ui/{custom_nodes,models,input,output,temp,user}
    
    # Create venv if it doesn't exist
    if [ ! -d $VENV_DIR ]; then
      echo 'Creating ComfyUI virtual environment...'
      mkdir -p ${config.home.homeDirectory}/.config/comfy-ui
      ${pkgs.python3}/bin/python3 -m venv $VENV_DIR
      $VENV_DIR/bin/pip install --upgrade pip
    fi
    
    # Install all dependencies declaratively
    if [ ! -f ${config.home.homeDirectory}/.config/comfy-ui/.deps_complete ]; then
      echo 'Installing ComfyUI dependencies...'
      $VENV_DIR/bin/pip install -r ${config.home.homeDirectory}/.config/comfy-ui/app/requirements.txt
      $VENV_DIR/bin/pip install segment-anything dill facexlib piexif insightface deepdiff webcolors ultralytics py-cpuinfo gguf llama-cpp-python onnxruntime imageio-ffmpeg opencv-python numba pynvml timm
      touch ${config.home.homeDirectory}/.config/comfy-ui/.deps_complete
    fi
    
    cd ${config.home.homeDirectory}/.config/comfy-ui/app
    exec $VENV_DIR/bin/python main.py --base-dir ${config.home.homeDirectory}/.config/comfy-ui --listen 0.0.0.0 "$@"
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
