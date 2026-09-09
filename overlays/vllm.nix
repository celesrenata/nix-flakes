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
  
  # qutlass rev must match what vLLM expects: it compiles _qutlass_C with
  # -DTORCH_TARGET_VERSION and USE_SABI (stable ABI). Older revs include the full
  # ATen/torch headers, which torch 2.13.0 hard-#errors under stable-only. This
  # rev (vLLM's pinned _QUTLASS_UPSTREAM_TAG) uses torch/csrc/stable/library.h +
  # torch::stable::Tensor, so it compiles clean against torch 2.13.0.
  qutlass = prev.fetchFromGitHub {
    name = "qutlass-source";
    owner = "IST-DASLab";
    repo = "qutlass";
    rev = "e74319e3405ce6d71965732880f5dc1f52371f64";
    hash = "sha256-Gzl3KuYXXLXMrVciEYrBPu1FH2cplGUPTFpWzFfUmMo=";
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

  # vLLM 0.27.1 added a FlashKDA (linear-attention decode) external project that
  # cmake fetches via git at configure time (cmake/external_projects/flashkda.cmake).
  # The build sandbox has no network/git, so provide the source and point
  # FLASH_KDA_SRC_DIR at it (the cmake honors that env var). Needs the cutlass
  # submodule. FlashKDA is enabled for sm_120 (arch 12.0f) on CUDA 13.
  flashkda = prev.fetchFromGitHub {
    name = "flashkda-source";
    owner = "vllm-project";
    repo = "FlashKDA";
    rev = "a3e42bbbece3bb38f7c426b880315294a336e82f";
    hash = "sha256-28OM4F9mvAzwcHB91dvrgh0kgSWX6sDEUOJBPzWVxWw=";
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
  # torch 2.13.0's kineto CUDA::cupti target (defined in our postPatch) reads
  # $ENV{CUPTI_INCLUDE_DIR}. nixpkgs' torch preConfigure sets that to
  # ${getDev cuda_cupti}/include, but on CUDA 13.2 the cupti headers live in the
  # "include" output (not "dev"), so that path does not exist and CMake's
  # generate step fails. Point at the correct output.
  cudaCuptiIncludeDir = "${prev.lib.getOutput "include" prev.cudaPackages.cuda_cupti}/include";

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

      # Torch builds fine with CUDA 13 but the pythonMetadataCheck hook references
      # a python env built for a different closure. Skip the check.
      # Use distcc to distribute C++ compilation across all 4 gremlins.
      #
      # vLLM 0.27.1 pins torch==2.13.0, which nixpkgs does not package (its
      # torch source build is version-locked to 2.12.0 via an assert in
      # pkgs/development/python-modules/torch/source/src.nix, which hand-unrolls
      # every third_party submodule). Rather than replicate ~37 submodule pins,
      # override .src directly with a single fetchFromGitHub that pulls the
      # v2.13.0 tag WITH submodules. Overriding .src bypasses src.nix entirely,
      # so the 2.12.0 assert never fires and git resolves each submodule to the
      # exact commit pinned by v2.13.0's tree.
      # Source hash from: nix-prefetch-git --fetch-submodules
      #   rev refs/tags/v2.13.0 -> cf30153c4c131c8164ee7798e5022d810682e2cb
      #
      # withNvshmem=false: NVSHMEM is a multi-GPU one-sided-comms library.
      # esnixi is a single-GPU (Blackwell) box, so it is unused at runtime, and
      # building cudaPackages.libnvshmem from source compiles a ~784-target
      # test/perftest suite that dwarfs torch itself. Disable it.
      torch = (pyprev.torch.override { withNvshmem = false; }).overridePythonAttrs (old: {
        version = "2.13.0";
        src = prev.fetchFromGitHub {
          owner = "pytorch";
          repo = "pytorch";
          rev = "v2.13.0";
          fetchSubmodules = true;
          hash = "sha256-L0hAyN6MrOlTSUpJ5Y735t53V2JPuZ82hffufh6Egh4=";
        };
        dontCheckPythonMetadata = true;
        # nixpkgs' torch postPatch (appended below via `old.postPatch`) already
        # rewrites pyproject.toml's "setuptools>=77.0.0,<82" -> "setuptools" with
        # --replace-fail, which matches torch 2.13.0's actual string. Do NOT
        # pre-normalize that pyproject line here: an earlier version of this
        # overlay rewrote it to "setuptools>=70.1.0,<82" to match a 2.12.0-era
        # nixpkgs, but current nixpkgs expects the verbatim ">=77.0.0,<82"
        # string, so pre-normalizing consumed it and made upstream's
        # --replace-fail abort ("pattern ... doesn't match anything").
        # The setup.py guard is retained (harmless: only appends if missing).
        postPatch = ''
          if ! grep -q "setuptools<82" setup.py; then
            printf '\n# nixpkgs-compat: setuptools<82\n' >> setup.py
          fi

          # torch 2.13.0's kineto (third_party/kineto/libkineto/CMakeLists.txt)
          # detects CUPTI via find_package(CUDAToolkit) + the CUDA::cupti target.
          # That target is only created if CMake's FindCUDAToolkit finds cupti
          # under CUDAToolkit_ROOT_DIR/extras/CUPTI -- but nixpkgs uses split CUDA
          # packages (cupti in its own store path) and points the toolkit root at
          # cuda_nvcc, so the target is never created and the build aborts.
          # pytorch 2.13.0 does not read CMAKE_ARGS (it forwards only BUILD_*/
          # USE_*/CMAKE_*/passthrough env vars via cmake/EnvVarForwarding.cmake),
          # so cmake-flag injection cannot reach FindCUDAToolkit here.
          # Instead, define the CUDA::cupti imported target ourselves from the
          # CUPTI_INCLUDE_DIR / CUPTI_LIBRARY_DIR env vars that nixpkgs' own torch
          # preConfigure already exports (pointing at cudaPackages.cuda_cupti).
          substituteInPlace third_party/kineto/libkineto/CMakeLists.txt \
            --replace-fail \
              'find_package(CUDAToolkit REQUIRED)' \
              'find_package(CUDAToolkit REQUIRED)
  if(NOT TARGET CUDA::cupti AND DEFINED ENV{CUPTI_INCLUDE_DIR} AND DEFINED ENV{CUPTI_LIBRARY_DIR})
    add_library(CUDA::cupti UNKNOWN IMPORTED)
    set_target_properties(CUDA::cupti PROPERTIES
      IMPORTED_LOCATION "$ENV{CUPTI_LIBRARY_DIR}/libcupti.so"
      INTERFACE_INCLUDE_DIRECTORIES "$ENV{CUPTI_INCLUDE_DIR}")
    message(STATUS "kineto: defined CUDA::cupti from nixpkgs CUPTI env hints")
  endif()'
        '' + (old.postPatch or "");
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.distcc prev.ccache ];
        preConfigure = (old.preConfigure or "") + ''
          export DISTCC_DIR="$TMPDIR/distcc"
          mkdir -p "$DISTCC_DIR"
          export DISTCC_HOSTS="localhost/16 10.1.1.12/16,lzo 10.1.1.13/16,lzo 10.1.1.14/16,lzo 10.1.1.15/16,lzo"
          export CMAKE_CXX_COMPILER_LAUNCHER="distcc;ccache"
          export CMAKE_C_COMPILER_LAUNCHER="distcc;ccache"
          export CMAKE_CUDA_COMPILER_LAUNCHER=ccache
          export CCACHE_DIR=$TMPDIR/ccache
          export CCACHE_MAXSIZE=50G
          mkdir -p $TMPDIR/ccache
          export MAX_JOBS=64
          # Correct CUPTI_INCLUDE_DIR: nixpkgs points it at the (nonexistent on
          # CUDA 13.2) cuda_cupti "dev" include; headers are in the "include"
          # output. Our kineto CUDA::cupti postPatch reads this env var.
          export CUPTI_INCLUDE_DIR="${cudaCuptiIncludeDir}"
          # Build only for esnixi's GPU (Blackwell sm_120). nixpkgs' default
          # gpuTargets for CUDA 13 emits a broad arch list that includes both
          # sm_103 and the family-specific sm_103f, which nvcc 13.2 rejects
          # ("same GPU code sm_103f generated for non family-specific and
          # family-specific GPU arch"). Restricting to 12.0 fixes that and
          # matches the vllm build's CMAKE_CUDA_ARCHITECTURES=120 / arch 12.0.
          export TORCH_CUDA_ARCH_LIST="12.0"
        '';
        __noChroot = true;
      });

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

      # xformers 0.0.35 is rebuilt from source in this scope against torch
      # 2.13.0 and runs its pytest suite in checkPhase. 24 CPU
      # torch.utils.checkpoint tests fail with "IndexError: list assignment
      # index out of range" -- a test-only incompatibility with torch 2.13.0's
      # checkpoint API, not a functional defect in the parts vLLM uses. Skip the
      # test suite (nixpkgs commonly does this for xformers).
      xformers = pyprev.xformers.overridePythonAttrs (old: {
        doCheck = false;
        dontUsePytestCheck = true;
      });

      flashinfer = pyprev.flashinfer.overridePythonAttrs (old: {
        __noChroot = true;
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.distcc prev.ccache ];
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

      # tokenspeed-mla depends on tokenspeed-triton which fails to build with CUDA 13.
      # vLLM lists it in pythonRemoveDeps but the env still resolves it. Stub it out.
      tokenspeed-mla = pyprev.buildPythonPackage {
        pname = "tokenspeed-mla";
        version = "0.1.5";
        format = "other";
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/${pyprev.python.sitePackages}/tokenspeed_mla
          echo "" > $out/${pyprev.python.sitePackages}/tokenspeed_mla/__init__.py
        '';
      };

      # nixpkgs gguf version (9967, llama.cpp rev) doesn't match metadata (0.19.0)
      gguf = pyprev.gguf.overridePythonAttrs (old: {
        dontCheckPythonMetadata = true;
      });

      # CUDA 13 moved crt/host_config.h to a separate cuda_crt package
      bitsandbytes = pyprev.bitsandbytes.overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or []) ++ [
          prev.cudaPackages.cuda_crt
        ];
      });
      
    };
  };
in {
  python3 = python3-for-vllm;
  python3Packages = python3-for-vllm.pkgs;
  vllm = python3-for-vllm.pkgs.vllm.overridePythonAttrs (old: {
    __noChroot = true;
    version = "0.27.1";
    src = prev.fetchFromGitHub {
      owner = "vllm-project";
      repo = "vllm";
      tag = "v0.27.1";
      hash = "sha256-1cl0Cn6nCj2DpP3uNRrtzOdZkO5Vila1GCQGY2xdib4=";
    };
    
    patches = [ ../patches/vllm-sm120-fp4-support.patch ];
    cargoRoot = "rust";
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      src = prev.fetchFromGitHub {
        owner = "vllm-project";
        repo = "vllm";
        tag = "v0.27.1";
        hash = "sha256-1cl0Cn6nCj2DpP3uNRrtzOdZkO5Vila1GCQGY2xdib4=";
      };
      sourceRoot = "source/rust";
      hash = "sha256-lcZZF6Oo2F2Nol7ULQ7TsBFDUJ+IDkv1/5HUQYuvBRo=";
    };
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
      # amd-quark (AMD Quark quantization) is only imported lazily when loading a
      # Quark-quantized model; on esnixi's NVIDIA Blackwell GPU it is never used.
      # Its closure pulls onnxscript -> onnxruntime (a multi-hour CUDA build) for
      # no runtime benefit here, so drop it.
      "amd-quark"
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

    # Drop amd-quark (and thus its onnxscript -> onnxruntime CUDA build) from the
    # actual inputs, not just the metadata check. AMD Quark quantization is
    # unused on esnixi's NVIDIA GPU and is only imported lazily by vLLM.
    dependencies =
      builtins.filter (x: (x.pname or x.name or "") != "amd-quark") (old.dependencies or []);

    propagatedBuildInputs =
      (builtins.filter (x: (x.pname or x.name or "") != "amd-quark")
        (old.propagatedBuildInputs or [])) ++ [
      python3-for-vllm.pkgs.ijson
      python3-for-vllm.pkgs.mcp
      python3-for-vllm.pkgs.grpcio-reflection
      python3-for-vllm.pkgs.tvm-ffi
      python3-for-vllm.pkgs.nvidia-cudnn-frontend
    ];
    
    preConfigure = (old.preConfigure or "") + ''
      export CMAKE_ARGS="-DFETCHCONTENT_SOURCE_DIR_CUTLASS=${cutlass} -DCMAKE_CUDA_ARCHITECTURES=120 $CMAKE_ARGS"
      export TRITON_KERNELS_SRC_DIR="${triton-kernels}/python/triton_kernels/triton_kernels"
      export FLASH_MLA_SRC_DIR="${flashmla}"
      export VLLM_FLASH_ATTN_SRC_DIR="${vllm-flash-attn}"
      export QUTLASS_SRC_DIR="${qutlass}"
      export DEEPGEMM_SRC_DIR="${deepgemm}"
      export FMHA_SM100_SRC_DIR="${fmha-sm100}"
      export TML_FA4_SRC_DIR="${tml-fa4}"
      export FLASH_KDA_SRC_DIR="${flashkda}"
    '';
    
    env = (old.env or {}) // {
      TORCH_CUDA_ARCH_LIST = "12.0";
      VLLM_TARGET_DEVICE = "cuda";
      FLASH_ATTN_CUDA_ARCHS = "120";
      VLLM_REQUIRE_RUST_FRONTEND = "0";
    };

    meta = (old.meta or {}) // {
      knownVulnerabilities = [];
      # nixpkgs marks its vllm build broken, but this overlay replaces the
      # source with a working build. Un-break it.
      broken = false;
    };
  });
}
