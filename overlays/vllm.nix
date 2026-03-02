final: prev: 
let
  cython_3_1_1 = prev.python312Packages.buildPythonPackage rec {
    pname = "cython";
    version = "3.1.1";
    src = prev.fetchPypi {
      inherit pname version;
      hash = "sha256-UFzNQTZp1RMqU4NNeSxweXQkgIjE9gxJfesbQW42Y5c=";
    };
    format = "pyproject";
    nativeBuildInputs = [ prev.python312Packages.setuptools ];
  };
in
let
  cutlass = prev.fetchFromGitHub {
    name = "cutlass-source";
    owner = "NVIDIA";
    repo = "cutlass";
    tag = "v4.2.1";
    hash = "sha256-iP560D5Vwuj6wX1otJhwbvqe/X4mYVeKTpK533Wr5gY=";
  };
  
  cutlass-flashmla = prev.fetchFromGitHub {
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "147f5673d0c1c3dcf66f78d677fd647e4a020219";
    hash = "sha256-dHQto08IwTDOIuFUp9jwm1MWkFi8v2YJ/UESrLuG71g=";
  };
  
  flashmla = prev.stdenv.mkDerivation {
    pname = "flashmla";
    version = "1.0.0";
    src = prev.fetchFromGitHub {
      name = "FlashMLA-source";
      owner = "vllm-project";
      repo = "FlashMLA";
      rev = "c2afa9cb93e674d5a9120a170a6da57b89267208";
      hash = "sha256-pKlwxV6G9iHag/jbu3bAyvYvnu5TbrQwUMFV0AlGC3s=";
    };
    dontConfigure = true;
    buildPhase = ''
      rm -rf csrc/cutlass
      ln -sf ${cutlass-flashmla} csrc/cutlass
    '';
    installPhase = "cp -rva . $out";
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
  
  vllm-flash-attn = prev.stdenv.mkDerivation {
    pname = "vllm-flash-attn";
    version = "2.7.2.post1";
    src = prev.fetchFromGitHub {
      name = "flash-attention-source";
      owner = "vllm-project";
      repo = "flash-attention";
      rev = "188be16520ceefdc625fdf71365585d2ee348fe2";
      hash = "sha256-Osec+/IF3+UDtbIhDMBXzUeWJ7hDJNb5FpaVaziPSgM=";
    };
    patches = [
      (prev.fetchpatch {
        url = "https://github.com/Dao-AILab/flash-attention/commit/dad67c88d4b6122c69d0bed1cebded0cded71cea.patch";
        hash = "sha256-JSgXWItOp5KRpFbTQj/cZk+Tqez+4mEz5kmH5EUeQN4=";
      })
      (prev.fetchpatch {
        url = "https://github.com/Dao-AILab/flash-attention/commit/e26dd28e487117ee3e6bc4908682f41f31e6f83a.patch";
        hash = "sha256-NkCEowXSi+tiWu74Qt+VPKKavx0H9JeteovSJKToK9A=";
      })
    ];
    dontConfigure = true;
    buildPhase = ''
      rm -rf csrc/cutlass
      ln -sf ${cutlass} csrc/cutlass
    '';
    installPhase = "cp -rva . $out";
  };
  
  python312-for-vllm = prev.python312.override {
    packageOverrides = pyfinal: pyprev: {
      grpcio-tools = pyprev.grpcio-tools.overridePythonAttrs (old: rec {
        version = "1.78.0";
        src = prev.fetchPypi {
          pname = "grpcio_tools";
          inherit version;
          hash = "sha256-Sw3YZWAnQxbhVdklFYJ2+FZFCBkwiLxD4g0/Xf+Vays=";
        };
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ cython_3_1_1 ];
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
          pyprev.typer
        ];
      });
      
      transformers = pyprev.transformers.overridePythonAttrs (old: rec {
        version = "5.2.0";
        src = prev.fetchFromGitHub {
          owner = "huggingface";
          repo = "transformers";
          rev = "v${version}";
          hash = "sha256-vus4Y+1QXUNqwBO1ZK0gWd+sJBPwrqWW7O2sn0EBvno=";
        };
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ 
          pyprev.typer 
          pyprev.httpx
        ];
        pythonRelaxDeps = true;
        doCheck = false;
      });
      
      compressed-tensors = pyprev.compressed-tensors.overridePythonAttrs (old: rec {
        version = "0.13.0";
        src = prev.fetchFromGitHub {
          owner = "vllm-project";
          repo = "compressed-tensors";
          rev = version;
          hash = "sha256-XsQRP186ISarMMES3P+ov4t/1KKJdl0tXBrfpjyM3XA=";
        };
        propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [ pyprev.loguru ];
        doCheck = false;
      });
    };
  };
in {
  vllm = python312-for-vllm.pkgs.vllm.overridePythonAttrs (old: {
    version = "0.16.0";
    src = prev.fetchFromGitHub {
      owner = "vllm-project";
      repo = "vllm";
      rev = "89a77b10846fd96273cce78d86d2556ea582d26e";
      hash = "sha256-7E67xVRlKmm+Hbp5nphhwH8SQC9LpCFNBfF2ZAOt79k=";
    };
    
    patches = [];
    
    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace-fail \
          'set(PYTHON_SUPPORTED_VERSIONS' \
          'set(PYTHON_SUPPORTED_VERSIONS "${prev.lib.versions.majorMinor python312-for-vllm.pkgs.python.version}"'
    '';
    
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
      python312-for-vllm.pkgs.grpcio-tools
    ];
    
    propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ [
      python312-for-vllm.pkgs.ijson
      python312-for-vllm.pkgs.mcp
      python312-for-vllm.pkgs.grpcio-reflection
    ];
    
    preBuild = ''
      export CMAKE_ARGS="-DFETCHCONTENT_SOURCE_DIR_CUTLASS=${cutlass} -DFLASH_MLA_SRC_DIR=${flashmla} -DVLLM_FLASH_ATTN_SRC_DIR=${vllm-flash-attn} -DQUTLASS_SRC_DIR=${qutlass} -DTORCH_CUDA_ARCH_LIST=12.0 -DCUTLASS_NVCC_ARCHS_ENABLED=120"
      export TRITON_KERNELS_SRC_DIR="${triton-kernels}/python/triton_kernels/triton_kernels"
    '';
    
    env = (old.env or {}) // {
      VLLM_TARGET_DEVICE = "cuda";
    };
  });
}
