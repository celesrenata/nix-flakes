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
    tag = "v3.6.0";
    hash = "sha256-JFSpQn+WsNnh7CAPlcpOcUp0nyKXNbJEANdXqmkt4Tc=";
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
    version = "2025-04-18";
    src = prev.fetchFromGitHub {
      name = "FlashMLA-source";
      owner = "vllm-project";
      repo = "FlashMLA";
      rev = "692917b1cda61b93ac9ee2d846ec54e75afe87b1";
      hash = "sha256-2nSrEUqdhYT6kI+wQTz+LJGEerDIznJR8oOlrVSQceg=";
    };
    dontConfigure = true;
    buildPhase = "true";
    installPhase = "cp -rva . $out";
  };
  
  deepgemm = prev.fetchFromGitHub {
    name = "deepgemm-source";
    owner = "deepseek-ai";
    repo = "DeepGEMM";
    rev = "477618cd51baffca09c4b0b87e97c03fe827ef03";
    hash = "sha256-7I1O9DDBGzij2NIjf8tQPFMCpTnyzMRdv1+bP3APOOc=";
    fetchSubmodules = true;
  };

  vllm-flash-attn = prev.fetchFromGitHub {
    name = "vllm-flash-attn-source";
    owner = "vllm-project";
    repo = "flash-attention";
    rev = "f5bc33cfc02c744d24a2e9d50e6db656de40611c";
    hash = "sha256-jEjn1DVqq2BcR1tsLUQ42G3EtomH6T33lkXUxAVD5uI=";
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
        doCheck = false;
      };

      mistral-common = pyprev.mistral-common.overridePythonAttrs (old: rec {
        version = "1.11.0";
        src = prev.fetchFromGitHub {
          owner = "mistralai";
          repo = "mistral-common";
          tag = "v${version}";
          hash = "sha256-DejbLY2i6Hp1J+spxMut5RKugj7rDyrZmp6v+5wqyWY=";
        };
        doCheck = false;
        pythonRuntimeDepsCheck = false;
      });

      compressed-tensors = pyprev.compressed-tensors.overridePythonAttrs (old: rec {
        version = "0.15.0.1";
        src = prev.fetchFromGitHub {
          owner = "vllm-project";
          repo = "compressed-tensors";
          rev = version;
          hash = "sha256-iiYo3Vne2CYlj+wMHxQFTTU7gb8oNwPtCe873nX5KgA=";
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
    version = "0.20.0";
    src = prev.fetchFromGitHub {
      owner = "vllm-project";
      repo = "vllm";
      tag = "v0.20.0";
      hash = "sha256-TUqkywqWQdnF+jzm3UYVAD5qe8jUK63f8nrZQaNnuZc=";
    };
    
    patches = [];
    postPatch = "";
    pythonCatchConflicts = false;
    pythonRuntimeDepsCheck = false;
    pythonRelaxDeps = true;
    pythonRemoveDeps = [
      "opentelemetry-semantic-conventions-ai"
      "flashinfer-cubin"
      "nvidia-cudnn-frontend"
      "fastsafetensors"
      "nvidia-cutlass-dsl"
      "quack-kernels"
    ];
    
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
      python313-for-vllm.pkgs.grpcio-tools
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
    };
  });
}
