final: prev: {
  ollama = final.unstable.ollama.override {
    # Use GCC 13 from unstable instead of 14 to avoid CUDA compilation issues
    stdenv = final.unstable.gcc13Stdenv;
  };
}
