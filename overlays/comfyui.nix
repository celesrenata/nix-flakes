final: prev: {
  comfyui = prev.python3Packages.buildPythonApplication rec {
    pname = "comfyui";
    version = "0.16.4";
    format = "other";

    src = prev.fetchFromGitHub {
      owner = "Comfy-Org";
      repo = "ComfyUI";
      rev = "v${version}";
      hash = "sha256-wPPsXQytzpb7gSzE4dUT5JME/q03Z2g6pk9RidHNy8A=";
    };

    frontend = prev.fetchFromGitHub {
      owner = "Comfy-Org";
      repo = "ComfyUI_frontend";
      rev = "v1.42.2";
      hash = "sha256-2aPnZf9sCx1oi/kiN4XPretV8Zhz2KJFw5vvXnBpUv4=";
    };

    manager = prev.fetchFromGitHub {
      owner = "Comfy-Org";
      repo = "ComfyUI-Manager";
      rev = "4.1b2";
      hash = "sha256-xq0APgYuaaqREFSF2/dPDQAkKIiXbmvg7n2RKl2K6U0=";
    };

    workflows = prev.fetchFromGitHub {
      owner = "Comfy-Org";
      repo = "workflows";
      rev = "main";
      hash = "sha256-YIN0tniels4xpCm9xHnIJP4EcZurHOy8Y2fw07ylpcw=";
    };

    docs = prev.fetchFromGitHub {
      owner = "Comfy-Org";
      repo = "docs";
      rev = "main";
      hash = "sha256-c11AZx9Rx2Sp57FWQZrpjEoNXzxyCBRy+k9m9w3JZw8=";
    };

    nativeBuildInputs = [ prev.makeWrapper prev.uv prev.python3Packages.pip ];

    dontBuild = true;

    propagatedBuildInputs = with prev.python3Packages; [
      aiohttp
      numpy
      pillow
      psutil
      pyyaml
      safetensors
      scipy
      torch
      torchaudio
      torchvision
      tqdm
      transformers
      gitpython
      opencv4
      piexif
      numba
      gguf
      pip
      ultralytics
      insightface
      diffusers
      huggingface-hub
      accelerate
      xformers
    ] ++ [ prev.uv ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/{bin,opt/comfyui}
      cp -r ./ $out/opt/comfyui/

      # Install frontend
      cp -r ${frontend} $out/opt/comfyui/web

      # Install manager
      mkdir -p $out/opt/comfyui/custom_nodes
      cp -r ${manager} $out/opt/comfyui/custom_nodes/ComfyUI-Manager

      # Install workflows
      mkdir -p $out/opt/comfyui/user/default
      cp -r ${workflows} $out/opt/comfyui/user/default/workflows

      # Install docs
      cp -r ${docs} $out/opt/comfyui/comfyui-embedded-docs

      makeWrapper /bin/sh $out/bin/comfyui \
        --add-flags "-c" \
        --add-flags "cd $out/opt/comfyui && exec \''${XDG_CONFIG_HOME:-\$HOME/.config}/comfy-ui/venv/bin/python main.py --base-dir \''${XDG_CONFIG_HOME:-\$HOME/.config}/comfy-ui \$*" \
        --prefix PATH : ${prev.uv}/bin:${prev.python3Packages.pip}/bin

      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "The most powerful and modular diffusion model GUI, api and backend with a graph/nodes interface";
      homepage = "https://github.com/comfyanonymous/ComfyUI";
      license = licenses.gpl3Only;
      platforms = platforms.all;
    };
  };
}
