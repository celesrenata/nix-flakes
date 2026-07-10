{ config, pkgs, inputs, ... }:

let
  comfyui = pkgs.comfyui;
  homeDir = config.home.homeDirectory;
  comfyHome = "${homeDir}/.config/comfy-ui";
  venvDir = "${comfyHome}/venv";
  uv = "${pkgs.uv}/bin/uv";

  comfyui-wrapper = pkgs.writeShellScript "comfyui-wrapper" ''
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.glib.out}/lib:${pkgs.libGL}/lib:${pkgs.libGLU}/lib:${pkgs.glib}/lib:${pkgs.libxcb}/lib:${pkgs.xorg.libX11}/lib:/run/opengl-driver/lib:''${LD_LIBRARY_PATH:-}

    # Sync ComfyUI source from nix store on version change
    if [ ! -f ${comfyHome}/app/.version ] || [ "$(cat ${comfyHome}/app/.version)" != "${comfyui.version}" ]; then
      echo "Syncing ComfyUI ${comfyui.version} source..."
      rm -rf ${comfyHome}/app
      cp -r ${comfyui}/opt/comfyui ${comfyHome}/app
      chmod -R u+w ${comfyHome}/app
      echo "${comfyui.version}" > ${comfyHome}/app/.version
    fi

    # Create required directory structure
    mkdir -p ${comfyHome}/{custom_nodes,models,input,output,temp,user,database}
    mkdir -p ${comfyHome}/app/user

    # Create venv if missing
    if [ ! -d ${venvDir} ]; then
      echo "Creating virtual environment..."
      ${uv} venv --python ${pkgs.python3}/bin/python3 ${venvDir}
    fi

    # Install/sync dependencies on version change
    if [ ! -f ${comfyHome}/.deps-${comfyui.version} ]; then
      echo "Installing dependencies for ComfyUI ${comfyui.version}..."
      ${uv} pip install --python ${venvDir}/bin/python \
        -r ${comfyHome}/app/requirements.txt
      ${uv} pip install --python ${venvDir}/bin/python --reinstall-package transformers --reinstall-package huggingface-hub \
        'transformers>=4.50.3,<5' \
        'huggingface-hub>=0.34.0,<1.0'
      ${uv} pip install --python ${venvDir}/bin/python \
        pip pyyaml pycryptodome pyOpenSSL segment-anything dill facexlib \
        piexif insightface deepdiff webcolors ultralytics py-cpuinfo gguf \
        onnxruntime imageio-ffmpeg opencv-python numba pynvml timm natsort kernels \
        addict anthropic dynamicprompts evalidate ffmpeg-python PyWavelets torchdiffeq \
        hydra-core openai-agents surrealist
      # These may fail to build from source - install separately
      ${uv} pip install --python ${venvDir}/bin/python nunchaku || true
      ${uv} pip install --python ${venvDir}/bin/python cupy-cuda12x || true
      ${uv} pip install --python ${venvDir}/bin/python basicsr || true
      rm -f ${comfyHome}/.deps-*
      touch ${comfyHome}/.deps-${comfyui.version}
    fi

    cd ${comfyHome}/app
    exec ${venvDir}/bin/python main.py --base-directory ${comfyHome} --listen 0.0.0.0 "$@"
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
      ExecStart = "${comfyui-wrapper} --port 8188";
      Restart = "on-failure";
      RestartSec = 5;
      Environment = [
        "COMFY_HOME=${comfyHome}"
        "BASE_DIR=${comfyHome}"
        "COMFYUI_MANAGER_SECURITY_LEVEL=weak"
        "VIRTUAL_ENV=${venvDir}"
        "PATH=${venvDir}/bin:${pkgs.uv}/bin:/run/current-system/sw/bin"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
