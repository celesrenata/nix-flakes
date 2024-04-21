final: prev:
rec {
  onnxruntimeOverride = prev.onnxruntime.overrideAttrs (old: {
    cudaSupport = true;
  });
}