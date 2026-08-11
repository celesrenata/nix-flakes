# Fix CUDA toolkit discovery for ollama (RTX 5090 Blackwell, sm_120)
# nixpkgs CUDA_PATH references "cuda-merged" but actual store path is "cuda-merged-12"
final: prev:
let
  ollamaBase = prev.ollama.override {
    acceleration = "cuda";
    cudaArches = [ "120" ];
  };
  cudaMerged = prev.cudaPackages.cudatoolkit;
in {
  ollama = ollamaBase.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.distcc prev.ccache ];
    preBuild = ''
      export CUDAToolkit_ROOT=${cudaMerged}
      export CUDA_PATH=${cudaMerged}
      export DISTCC_DIR="$TMPDIR/distcc"
      mkdir -p "$DISTCC_DIR"
      export DISTCC_HOSTS="localhost/16 10.1.1.12/16,lzo 10.1.1.13/16,lzo 10.1.1.14/16,lzo 10.1.1.15/16,lzo"
      export CMAKE_C_COMPILER_LAUNCHER="distcc;ccache"
      export CMAKE_CXX_COMPILER_LAUNCHER="distcc;ccache"
      export CMAKE_CUDA_COMPILER_LAUNCHER=ccache
      export CCACHE_DIR=/var/cache/ccache
      export CCACHE_MAXSIZE=50G
      mkdir -p /var/cache/ccache
    '' + (old.preBuild or "");
    __noChroot = true;
  });
}
