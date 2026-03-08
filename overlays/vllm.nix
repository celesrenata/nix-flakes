# vLLM Overlay - Update to v0.16.0 for LLM serving
# Provides a newer version of vLLM for large language model inference

final: prev: {
  python3Packages.vllm = prev.python3Packages.buildPythonPackage rec {
    pname = "vllm";
    version = "0.16.0";
    
    format = "wheel";
    
    wheelUrl = "https://files.pythonhosted.org/packages/${final.lib.strings.getFilenameFromURL (prev.python3Packages.pypi."${pname}/${version}".sourceUrls.${final.system}.url)}";
    wheelHash = "sha256-PLACEHOLDER";  # Update with actual hash
    
    doCheck = false;
    
    propagatedBuildInputs = [
      final.python3Packages.torch
      final.python3Packages.transformers
      final.python3Packages.tiktoken
      final.python3Packages.tokenizers
    ];
    
    meta = with final.lib; {
      description = "vLLM: A high-throughput and memory-efficient inference and serving engine for LLMs";
      homepage = "https://github.com/vllm-project/vllm";
      license = licenses.asl20;
      maintainers = [];
      platforms = platforms.linux ++ platforms.windows;
    };
  };
}
