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
    preBuild = ''
      export CUDAToolkit_ROOT=${cudaMerged}
      export CUDA_PATH=${cudaMerged}
    '' + (old.preBuild or "");
  });
}
