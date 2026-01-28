final: prev: 
let
  cutlass = prev.fetchFromGitHub {
    name = "cutlass-source";
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v4.2.1";
    hash = "sha256-iP560D5Vwuj6wX1otJhwbvqe/X4mYVeKTpK533Wr5gY=";
  };
  
  triton-kernels = prev.fetchFromGitHub {
    owner = "triton-lang";
    repo = "triton";
    tag = "v3.5.0";
    hash = "sha256-F6T0n37Lbs+B7UHNYzoIQHjNNv3TcMtoXjNrT8ZUlxY=";
  };
  
  qutlass = prev.fetchFromGitHub {
    name = "qutlass-source";
    owner = "IST-DASLab";
    repo = "qutlass";
    rev = "830d2c4537c7396e14a02a46fbddd18b5d107c65";
    hash = "sha256-aG4qd0vlwP+8gudfvHwhtXCFmBOJKQQTvcwahpEqC84=";
  };
  
  cutlass-flashmla = prev.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v3.9.0";
    hash = "sha256-Q6y/Z6vahASeSsfxvZDwbMFHGx8CnsF90IlveeVLO9g=";
  };
  
  flashmla = prev.stdenv.mkDerivation {
    pname = "flashmla";
    version = "1.0.0";
    src = prev.fetchFromGitHub {
      name = "FlashMLA-source";
      owner = "vllm-project";
      repo = "FlashMLA";
      rev = "46d64a8ebef03fa50b4ae74937276a5c940e3f95";
      hash = "sha256-jtMzWB5hKz8mJGsdK6q4YpQbGp9IrQxbwmB3a64DIl0=";
    };
    dontConfigure = true;
    buildPhase = ''
      rm -rf csrc/cutlass
      ln -sf ${cutlass-flashmla} csrc/cutlass
    '';
    installPhase = "cp -rva . $out";
  };
  
  vllm-flash-attn = prev.stdenv.mkDerivation {
    pname = "vllm-flash-attn";
    version = "2.7.2.post1";
    src = prev.fetchFromGitHub {
      name = "vllm-flash-attn-source";
      owner = "vllm-project";
      repo = "flash-attention";
      rev = "188be16520ceefdc625fdf71365585d2ee348fe2";
      hash = "sha256-Osec+/IF3+UDtbIhDMBXzUeWJ7hDJNb5FpaVaziPSgM=";
    };
    patches = [ ../patches/flash-attn-cutlass-v4-compat.patch ];
    dontConfigure = true;
    buildPhase = ''
      rm -rf csrc/cutlass
      ln -sf ${cutlass} csrc/cutlass
    '';
    installPhase = "cp -rva . $out";
  };
in 
let
  python312-for-vllm = prev.python312.override {
    packageOverrides = pyfinal: pyprev: {
      compressed-tensors = pyprev.compressed-tensors.overridePythonAttrs (old: rec {
        version = "0.13.0";
        src = prev.fetchFromGitHub {
          owner = "vllm-project";
          repo = "compressed-tensors";
          rev = version;
          hash = "sha256-XsQRP186ISarMMES3P+ov4t/1KKJdl0tXBrfpjyM3XA=";
        };
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
          pyprev.loguru
        ];
        doCheck = false;
      });
      
      huggingface-hub = pyprev.huggingface-hub.overridePythonAttrs (old: rec {
        version = "1.3.0";
        src = prev.fetchFromGitHub {
          owner = "huggingface";
          repo = "huggingface_hub";
          rev = "v${version}";
          hash = "sha256-JEvVWoOc1U1pX4q1cf0A5i32KGx7zWCBBOeoLbCiyVw=";
        };
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
          pyprev.httpx
          pyprev.shellingham
          pyprev.typer-slim
        ];
      });
      
      transformers = pyprev.transformers.overridePythonAttrs (old: {
        src = prev.fetchFromGitHub {
          owner = "huggingface";
          repo = "transformers";
          rev = "main";
          hash = "sha256-XZhi1RyzcWF2/VCkbu+3743dwtSHR0Z+XrHcMZQvfps=";
        };
        version = "5.0.0-dev";
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
          pyprev.typer-slim
        ];
      });
    };
  };
in {
  vllm = python312-for-vllm.pkgs.vllm.overridePythonAttrs (old: {
    version = "0.14.1-dev";
    src = prev.fetchFromGitHub {
      owner = "vllm-project";
      repo = "vllm";
      rev = "main";
      hash = "sha256-rBbaLd8eb3lW4nM1PPl/lTVQrJHYIsj+bibwnlo/x44=";
    };
    
    patches = [];
    postPatch = "";
    pythonCatchConflicts = false;
    
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
      python312-for-vllm.pkgs.grpcio-tools
    ];
    
    propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
      python312-for-vllm.pkgs.ijson
      python312-for-vllm.pkgs.mcp
      python312-for-vllm.pkgs.grpcio-reflection
    ];
    
    preBuild = (old.preBuild or "") + ''
      export CMAKE_ARGS="-DFETCHCONTENT_SOURCE_DIR_CUTLASS=${cutlass} -DCMAKE_CUDA_ARCHITECTURES=120 $CMAKE_ARGS"
      export TRITON_KERNELS_SRC_DIR="${triton-kernels}/python/triton_kernels/triton_kernels"
      export FLASH_MLA_SRC_DIR="${flashmla}"
      export VLLM_FLASH_ATTN_SRC_DIR="${vllm-flash-attn}"
      export QUTLASS_SRC_DIR="${qutlass}"
    '';
    
    env = (old.env or {}) // {
      TORCH_CUDA_ARCH_LIST = "12.0";
      VLLM_TARGET_DEVICE = "cuda";
      FLASH_ATTN_CUDA_ARCHS = "120";
    };
  });
}
