final: prev: {
  comfyui = prev.python3Packages.buildPythonApplication rec {
    pname = "comfyui";
    version = "0.3.60";
    format = "other";

    src = prev.fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "v0.3.60";
      hash = "sha256-P4JR10gwxuA5PzfxXzkbbI0UfJfArPGevJ+/ukgYzW4=";
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
