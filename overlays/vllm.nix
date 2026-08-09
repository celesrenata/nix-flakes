final: prev: 
let
  cutlass = prev.fetchFromGitHub {
    name = "cutlass-source";
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v4.4.2";
    hash = "sha256-0q9Ad0Z6E/rO2PdM4uQc8H0E0qs9uKc3reHepiHhjEc=";
  };
  
  triton-kernels = prev.fetchFromGitHub {
    owner = "triton-lang";
    repo = "triton";
    tag = "v3.5.1";
    hash = "sha256-dyNRtS1qtU8C/iAf0Udt/1VgtKGSvng1+r2BtvT9RB4=";
  };
  
  qutlass = prev.fetchFromGitHub {
    name = "qutlass-source";
    owner = "IST-DASLab";
    repo = "qutlass";
    rev = "830d2c4537c7396e14a02a46fbddd18b5d107c65";
    hash = "sha256-aG4qd0vlwP+8gudfvHwhtXCFmBOJKQQTvcwahpEqC84=";
  };
  
  flashmla = prev.stdenv.mkDerivation {
    pname = "flashmla";
    version = "2025-06-15";
    src = prev.fetchFromGitHub {
      name = "FlashMLA-source";
      owner = "vllm-project";
      repo = "FlashMLA";
      rev = "a6ec2ba7bd0a7dff98b3f4d3e6b52b159c48d78b";
      hash = "sha256-Oj37H0swZdxaprpaHq0XfOCagc0ypYKpS8e6JzqcDQg=";
    };
    dontConfigure = true;
    buildPhase = "true";
    installPhase = "cp -rva . $out";
  };
  
  deepgemm = prev.fetchFromGitHub {
    name = "deepgemm-source";
    owner = "deepseek-ai";
    repo = "DeepGEMM";
    rev = "891d57b4db1071624b5c8fa0d1e51cb317fa709f";
    hash = "sha256-sQM8SFkcDJmzyvKl1nv+nkwWaHvvo7mOGyNot2oduJg=";
    fetchSubmodules = true;
  };

  vllm-flash-attn = prev.runCommand "vllm-flash-attn-source" {
    src = prev.fetchFromGitHub {
      name = "vllm-flash-attn-source";
      owner = "vllm-project";
      repo = "flash-attention";
      rev = "2c839c33742309ec41e620bf837495ec9926c56e";
      hash = "sha256-VwEcC3i76/ekhQX/01XAYa5koyQrxhasUd3HurTzJEs=";
      fetchSubmodules = true;
    };
  } ''
    cp -r $src $out
    chmod -R u+w $out
    # Add Python 3.14 to supported versions
    sed -i 's/"3.9" "3.10" "3.11" "3.12" "3.13"/"3.9" "3.10" "3.11" "3.12" "3.13" "3.14"/' $out/CMakeLists.txt
  '';

  fmha-sm100 = prev.fetchFromGitHub {
    name = "fmha-sm100-source";
    owner = "vllm-project";
    repo = "MSA";
    rev = "2e63ec37a0fc29bc20f39cd1a52e0f5affc33a73";
    hash = "sha256-TFW3THDfTn8Uf91+BhcY6ApU1jxxvzs5m0oxJ+kzgdM=";
    fetchSubmodules = true;
  };

  tml-fa4 = prev.fetchFromGitHub {
    name = "tml-fa4-source";
    owner = "vllm-project";
    repo = "tml-fa4";
    rev = "b206834606ed5b5f21f8eed6b0683f528ea9cf7d";
    hash = "sha256-LDA5bW4Bf5+w41K9aJ5flz372hy+Ukm//RT55L7nbbU=";
  };
in 
let
  python3-for-vllm = prev.python3.override {
    packageOverrides = pyfinal: pyprev: {
      tvm-ffi = pyprev.buildPythonPackage rec {
        pname = "tvm-ffi";
        version = "0.1";
        src = prev.fetchPypi {
          pname = "tvm-ffi";
          inherit version;
          hash = "sha256-aVyXxm01PwiOyMIObyqTCyKSuACAF53IJzhxs+Hy3xA=";
        };
        pyproject = true;
        build-system = [ pyprev.setuptools ];
        doCheck = false;
      };

      prometheus-fastapi-instrumentator = pyprev.prometheus-fastapi-instrumentator.overridePythonAttrs (old: rec {
        version = "8.0.2";
        src = prev.fetchPypi {
          pname = "prometheus_fastapi_instrumentator";
          inherit version;
          hash = "sha256-PCUudIFRdop679ZoJKBKhwFE9x3kimeu0hF0mpyipUg=";
        };
        doCheck = false;
      });
      mistral-common = pyprev.mistral-common.overridePythonAttrs (old: rec {
        version = "1.11.3";
        src = prev.fetchFromGitHub {
          owner = "mistralai";
          repo = "mistral-common";
          tag = "v${version}";
          hash = "sha256-9NeJqv7m7vT/lI6mV9QbAsrLUcxO4Wr+QgKfz6RWtsM=";
        };
        doCheck = false;
        pythonRuntimeDepsCheck = false;
      });

      compressed-tensors = pyprev.compressed-tensors.overridePythonAttrs (old: rec {
        version = "0.17.0";
        src = prev.fetchFromGitHub {
          owner = "vllm-project";
          repo = "compressed-tensors";
          rev = version;
          hash = "sha256-nQrpR/YhwwIU1KB5DHLA/EsQ4s4kSf21qYsnlhQySlA=";
        };
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
          pyprev.loguru
          pyprev.psutil
        ];
        doCheck = false;
      });

      flashinfer = pyprev.flashinfer.overridePythonAttrs (old: {
        version = "0.6.14";
        src = prev.fetchFromGitHub {
          owner = "flashinfer-ai";
          repo = "flashinfer";
          tag = "v0.6.14";
          fetchSubmodules = true;
          hash = "sha256-wqNtO/sDaMzFlxcIp43WGwsYJDGGOAqwbeFwwuUw6KY=";
        };
        dependencies = (old.dependencies or []) ++ [ pyprev.requests ];
        pythonRemoveDeps = (old.pythonRemoveDeps or []) ++ [
          "cuda-tile"
          "tilelang"
        ];
        dontCheckPythonMetadata = true;
      });

      outlines = pyprev.outlines.overridePythonAttrs (old: {
        # outlines 1.2.12 added pillow as a runtime dep but nixpkgs missed it
        dependencies = (old.dependencies or []) ++ [ pyprev.pillow ];
      });

      xgrammar = pyprev.xgrammar.overridePythonAttrs (old: {
        version = "0.2.1";
        src = prev.fetchFromGitHub {
          owner = "mlc-ai";
          repo = "xgrammar";
          tag = "v0.2.1";
          fetchSubmodules = true;
          hash = "sha256-h9ovM/HbbkrxHGlJNn8eEisD5fnfRGCwoSOwc6HgpVQ=";
        };
        patches = [];
        build-system = (old.build-system or []) ++ [ pyprev.apache-tvm-ffi ];
        doCheck = false;
        dontCheckPythonMetadata = true;
      });

      # nixpkgs sets doCheck = false for this package, but our python override scope
      # rebuilds it without that setting — re-apply it here
      model-hosting-container-standards = pyprev.model-hosting-container-standards.overridePythonAttrs (old: {
        doCheck = false;
      });

      # nixpkgs gguf version (9967, llama.cpp rev) doesn't match metadata (0.19.0)
      gguf = pyprev.gguf.overridePythonAttrs (old: {
        dontCheckPythonMetadata = true;
      });
      
    };
  };
in {
  vllm = python3-for-vllm.pkgs.vllm.overridePythonAttrs (old: {
    version = "0.26.0";
    src = prev.fetchFromGitHub {
      owner = "vllm-project";
      repo = "vllm";
      tag = "v0.26.0";
      hash = "sha256-jFzV6vQX88FhemF98HmT5j3t6Trj5lXVlym4WD/X+Kw=";
    };
    
    patches = [ ../patches/vllm-sm120-fp4-support.patch ];
    postPatch = ''
      sed -i 's/torch == 2.11.0/torch >= 2.11.0/' pyproject.toml
      find . -path '*/requirements*' -name '*.txt' -exec sed -i 's/torch==2.11.0/torch>=2.11.0/' {} +
      # Remove setuptools-rust from pyproject.toml build-system requires
      # (we provide it via nativeBuildInputs instead)
      sed -i '/setuptools-rust/d' pyproject.toml
      # Relax setuptools version upper bound (nixpkgs has 83.x, vllm wants <81)
      sed -i 's/"setuptools>=77.0.3,<81.0.0"/"setuptools>=77.0.3"/' pyproject.toml
    '';
    pythonCatchConflicts = false;
    pythonRuntimeDepsCheck = false;
    dontCheckRuntimeDeps = true;
    dontCheckPythonMetadata = true;
    pythonRelaxDeps = true;
    pythonRemoveDeps = [
      "opentelemetry-semantic-conventions-ai"
      "flashinfer-cubin"
      "nvidia-cudnn-frontend"
      "fastsafetensors"
      "nvidia-cutlass-dsl"
      "quack-kernels"
      "apache-tvm-ffi"
      "tilelang"
      "tokenspeed-mla"
      "humming-kernels"
    ];
    
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
      python3-for-vllm.pkgs.grpcio-tools
      (python3-for-vllm.pkgs.setuptools-rust.overrideAttrs (old: {
        setupHook = prev.writeText "setuptools-rust-hook-disabled" "";
      }))
    ];
    
    buildInputs = (old.buildInputs or []) ++ [
      python3-for-vllm.pkgs.torch
    ];
    
    propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
      python3-for-vllm.pkgs.ijson
      python3-for-vllm.pkgs.mcp
      python3-for-vllm.pkgs.grpcio-reflection
      python3-for-vllm.pkgs.tvm-ffi
      python3-for-vllm.pkgs.nvidia-cudnn-frontend
    ];
    
    preBuild = (old.preBuild or "") + ''
      export CMAKE_ARGS="-DFETCHCONTENT_SOURCE_DIR_CUTLASS=${cutlass} -DCMAKE_CUDA_ARCHITECTURES=120 $CMAKE_ARGS"
      export TRITON_KERNELS_SRC_DIR="${triton-kernels}/python/triton_kernels/triton_kernels"
      export FLASH_MLA_SRC_DIR="${flashmla}"
      export VLLM_FLASH_ATTN_SRC_DIR="${vllm-flash-attn}"
      export QUTLASS_SRC_DIR="${qutlass}"
      export DEEPGEMM_SRC_DIR="${deepgemm}"
      export FMHA_SM100_SRC_DIR="${fmha-sm100}"
      export TML_FA4_SRC_DIR="${tml-fa4}"
    '';
    
    env = (old.env or {}) // {
      TORCH_CUDA_ARCH_LIST = "12.0";
      VLLM_TARGET_DEVICE = "cuda";
      FLASH_ATTN_CUDA_ARCHS = "120";
      VLLM_REQUIRE_RUST_FRONTEND = "0";
    };

    meta = (old.meta or {}) // {
      knownVulnerabilities = [];
    };
  });
}
