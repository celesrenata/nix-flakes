final: prev: {
  comfyui = prev.python3Packages.buildPythonApplication rec {
    pname = "comfyui";
    version = "0.3.57-fixed";
    format = "other";

    src = prev.fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "v0.3.57";
      hash = "sha256-uqGqiPNGLM7rlyfNwRhXSqYQOiA11JGitF4RGNQowjc=";
    };

    nativeBuildInputs = [ prev.makeWrapper ];

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
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/{bin,opt/comfyui}
      cp -r ./ $out/opt/comfyui/

      makeWrapper ${prev.python3}/bin/python $out/bin/comfyui \
        --add-flags "$out/opt/comfyui/main.py" \
        --add-flags "--base-dir \''${XDG_DATA_HOME:-\$HOME/.local/share}/comfyui"

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
