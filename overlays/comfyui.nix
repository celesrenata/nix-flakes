# ComfyUI Overlay - Updated with working URLs

final: prev: {
  # Main ComfyUI package (unchanged)
  comfyui = prev.python3Packages.buildPythonApplication rec {
    pname = "comfyui";
    version = "0.3.68-unstable-2025-01-15";
    format = "other";

    src = prev.fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "9a0238256873711bd38ce0e0b1d15a617a1ee454";
      hash = "sha256-SD4+2aB8kjPM8TFc6yUYOkMH8bksHoTnP5uoNN/aySw=";
    };

    nativeBuildInputs = [ prev.makeWrapper prev.uv prev.python3Packages.pip ];

    dontBuild = true;

    propagatedBuildInputs = with prev.python3Packages; [
      aiohttp numpy pillow psutil pyyaml safetensors scipy torch torchaudio torchvision tqdm transformers gitpython opencv4 piexif numba gguf pip ultralytics insightface diffusers huggingface-hub accelerate xformers
    ] ++ [ prev.uv ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/{bin,opt/comfyui}
      cp -r ./ $out/opt/comfyui/
      
      makeWrapper /bin/sh $out/bin/comfyui \
        --add-flags "-c" \
        --add-flags "cd $out/opt/comfyui && exec ''${XDG_CONFIG_HOME:-\$HOME/.config}/comfy-ui/venv/bin/python main.py --base-dir ''${XDG_CONFIG_HOME:-\$HOME/.config}/comfy-ui \$*" \
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

  # Valid workflow templates package (optional)
  comfyui-workflow-templates = prev.python3Packages.buildPythonPackage rec {
    pname = "comfyui-workflow-templates";
    version = "2025-01-15";
    
    format = "other";
    
    src = prev.fetchFromGitHub {
      owner = "Comfy-Org";
      repo = "workflow_templates";
      rev = "refs/heads/main";
      hash = "sha256-placeholder";  # Update with actual hash after fetch
    };

    dontBuild = true;
    
    propagatedBuildInputs = [ ];
    
    installPhase = ''
      runHook preInstall
      mkdir -p $out/workflows
      
      # Copy valid workflow templates from the repository
      cp -r ${src}/templates/*.json $out/workflows/ 2>/dev/null || true
      cp -r ${src}/input/*.* $out/input/ 2>/dev/null || true
      
      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "Valid ComfyUI workflow templates and input files";
      homepage = "https://github.com/Comfy-Org/workflow_templates";
      license = licenses.mit;
      platforms = platforms.all;
    };
  };

  # Valid template URLs that work (from official manifest)
  comfyui-valid-templates = {
    text_to_image = "https://raw.githubusercontent.com/Comfy-Org/workflow_templates/main/templates/01_get_started_text_to_image.json";
    image_editing = "https://raw.githubusercontent.com/Comfy-Org/workflow_templates/main/templates/image_qwen_Image_2512_with_2steps_lora.json";
    
    # Valid input file URLs (from workflow_template_input_files.json)
    valid_inputs = {
      test_image = "https://raw.githubusercontent.com/Comfy-Org/workflow_templates/main/input/1950_new_york.png";
      character_front = "https://raw.githubusercontent.com/Comfy-Org/workflow_templates/main/input/3d_character_front_view.png";
    };
  };

}
