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

  vllm-flash-attn = prev.fetchFromGitHub {
    name = "vllm-flash-attn-source";
    owner = "vllm-project";
    repo = "flash-attention";
    rev = "dd62dac706b1cf7895bd99b18c6cb7e7e117ee25";
    hash = "sha256-r7YW0FlsF7eeUOyKeoq6wnJMykExVqwBCgh2y/w9nPk=";
    fetchSubmodules = true;
  };
in 
let
  python313-for-vllm = prev.python313.override {
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
        ];
        doCheck = false;
      });
      
    };
  };
in {
  vllm = python313-for-vllm.pkgs.vllm.overridePythonAttrs (old: {
    version = "0.23.0";
    src = prev.fetchFromGitHub {
      owner = "vllm-project";
      repo = "vllm";
      tag = "v0.23.0";
      hash = "sha256-9mxu2jLchoKmRzD71enPomVJuP5LjbUtQqLMdP5k+Qw=";
    };
    
    patches = [];
    postPatch = ''
      sed -i 's/torch == 2.11.0/torch >= 2.11.0/' pyproject.toml
      find . -path '*/requirements*' -name '*.txt' -exec sed -i 's/torch==2.11.0/torch>=2.11.0/' {} +
      # Remove setuptools-rust from pyproject.toml build-system requires
      # (we provide it via nativeBuildInputs instead)
      sed -i '/setuptools-rust/d' pyproject.toml
    '';
    pythonCatchConflicts = false;
    pythonRuntimeDepsCheck = false;
    dontCheckRuntimeDeps = true;
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
      python313-for-vllm.pkgs.grpcio-tools
      (python313-for-vllm.pkgs.setuptools-rust.overrideAttrs (old: {
        setupHook = prev.writeText "setuptools-rust-hook-disabled" "";
      }))
    ];
    
    buildInputs = (old.buildInputs or []) ++ [
      python313-for-vllm.pkgs.torch
    ];
    
    propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
      python313-for-vllm.pkgs.ijson
      python313-for-vllm.pkgs.mcp
      python313-for-vllm.pkgs.grpcio-reflection
      python313-for-vllm.pkgs.tvm-ffi
    ];
    
    preBuild = (old.preBuild or "") + ''
      export CMAKE_ARGS="-DFETCHCONTENT_SOURCE_DIR_CUTLASS=${cutlass} -DCMAKE_CUDA_ARCHITECTURES=120 $CMAKE_ARGS"
      export TRITON_KERNELS_SRC_DIR="${triton-kernels}/python/triton_kernels/triton_kernels"
      export FLASH_MLA_SRC_DIR="${flashmla}"
      export VLLM_FLASH_ATTN_SRC_DIR="${vllm-flash-attn}"
      export QUTLASS_SRC_DIR="${qutlass}"
      export DEEPGEMM_SRC_DIR="${deepgemm}"
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
