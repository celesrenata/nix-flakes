# Ollama overlay: bump to v0.32.13 (Qwen 3.8 support) + CUDA/distcc build fixes
final: prev:
let
  cudaMerged = prev.cudaPackages.cudatoolkit;

  # Updated llama.cpp pin for v0.32.13
  llamaCppSrc = prev.fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    tag = "b10380";
    hash = "sha256-HT0QuIFJz5cgH2qinxhtyLEL/RrUpziZuntj/EDQtzI=";
  };
in {
  ollama = (prev.ollama.override {
    acceleration = "cuda";
    cudaArches = [ "120" ];
  }).overrideAttrs (old: {
    version = "0.32.13";
    src = prev.fetchFromGitHub {
      owner = "ollama";
      repo = "ollama";
      tag = "v0.32.13";
      hash = "sha256-KSvw7LsvpUVeSm9BKJ4wIp/fWGHjMp8bOTMUpFJCDmw=";
    };
    vendorHash = "sha256-HMwoaFBMbpoy8f0I+O+i7kIa9BslLu3FcVWeaIOkpvs=";

    postPatch = ''
      substituteInPlace version/version.go \
        --replace-fail 0.0.0 '0.32.13'

      # Remove integration tests that need network/npm
      rm -f cmd/launch/*_test.go
      rm -rf app

      # Pre-stage llama.cpp for the FetchContent step and apply compat patch
      cp -r ${llamaCppSrc} $TMPDIR/llama-cpp-src
      chmod -R +w $TMPDIR/llama-cpp-src
      ( cd $TMPDIR/llama-cpp-src && \
        cmake -DPATCH_DIR=$NIX_BUILD_TOP/source/llama/compat \
          -P $NIX_BUILD_TOP/source/llama/compat/apply-patch.cmake )
    '';

    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.distcc prev.ccache ];

    preBuild = ''
      export CUDAToolkit_ROOT=${cudaMerged}
      export CUDA_PATH=${cudaMerged}
      export FETCHCONTENT_SOURCE_DIR_LLAMA_CPP=$TMPDIR/llama-cpp-src
      export DISTCC_DIR="$TMPDIR/distcc"
      mkdir -p "$DISTCC_DIR"
      export DISTCC_HOSTS="localhost/16 10.1.1.12/16,lzo 10.1.1.13/16,lzo 10.1.1.14/16,lzo 10.1.1.15/16,lzo"
      export CMAKE_C_COMPILER_LAUNCHER="distcc;ccache"
      export CMAKE_CXX_COMPILER_LAUNCHER="distcc;ccache"
      export CMAKE_CUDA_COMPILER_LAUNCHER=ccache
      export CCACHE_DIR="$TMPDIR/ccache"
      export CCACHE_MAXSIZE=50G
      mkdir -p "$TMPDIR/ccache"
    '' + (old.preBuild or "");

    __noChroot = true;
  });
}
