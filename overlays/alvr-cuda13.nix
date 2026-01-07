final: prev: {
  alvr = prev.alvr.override {
    cudaPackages = prev.cudaPackages_13;
  };
}
