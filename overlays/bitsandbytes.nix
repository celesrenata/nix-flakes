self: super: {
  # Temporarily disabled - testing if CUDA 12.8 works
  # python3 = super.python3.override {
  #   packageOverrides = python-self: python-super: {
  #     bitsandbytes = python-super.bitsandbytes.override {
  #       cudaPackages = self.cudaPackages_12_9;
  #     };
  #   };
  # };
}
