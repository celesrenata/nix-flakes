final: prev: {
  ollama = prev.ollama.override {
    # Use GCC 13 instead of 14 to avoid CUDA compilation issues
    stdenv = prev.gcc13Stdenv;
  };
}
