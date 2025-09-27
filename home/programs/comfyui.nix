{ config, pkgs, inputs, ... }:

let
  comfyui = inputs.nix-comfyui.packages.${pkgs.system}.default;
  
  comfyui-wrapper = pkgs.writeShellScript "comfyui-wrapper" ''
    export PATH="${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.nix}/bin:$PATH"
    
    # Define required functions
    parse_arguments() { true; }
    export_config() { true; }
    log_info() { echo "[INFO] $1"; }
    log_debug() { echo "[DEBUG] $1"; }
    debug_vars() { true; }
    install_all() { 
      mkdir -p "$COMFYUI_SRC" "$COMFY_MODELS_DIR" "$COMFY_OUTPUT_DIR" "$COMFY_INPUT_DIR" "$COMFY_TEMP_DIR" 2>/dev/null || true
    }
    start_comfyui() {
      PYTHON_ENV="$(nix-store -q --references ${comfyui} | grep python | head -1)"
      cd "${comfyui}/share/comfy-ui"
      exec "$PYTHON_ENV/bin/python" main.py "$@"
    }
    
    # Export functions so launcher can use them
    export -f parse_arguments export_config log_info log_debug debug_vars install_all start_comfyui
    
    # Call the original launcher
    exec ${comfyui}/bin/comfy-ui "$@"
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
        "COMFY_HOME=${config.home.homeDirectory}/.config/comfyui"
        "BASE_DIR=${config.home.homeDirectory}/.config/comfyui"
        "COMFY_MODELS_DIR=${config.home.homeDirectory}/.config/comfyui/models"
        "COMFY_OUTPUT_DIR=${config.home.homeDirectory}/.config/comfyui/output"
        "COMFY_INPUT_DIR=${config.home.homeDirectory}/.config/comfyui/input"
        "COMFY_TEMP_DIR=${config.home.homeDirectory}/.config/comfyui/temp"
        "COMFYUI_SRC=${config.home.homeDirectory}/.config/comfyui/ComfyUI"
        "PYTHONPATH=${config.home.homeDirectory}/.config/comfyui"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
