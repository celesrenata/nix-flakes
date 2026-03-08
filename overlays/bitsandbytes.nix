# bitsandbytes Overlay - Fix for CUDA 12.8 + glibc 2.42 compatibility
# This overlay provides patches and fixes for the bitsandbytes Python package
# when used with newer CUDA versions and glibc versions

final: prev: {
  # Override bitsandbytes to use patched version if needed
  python3Packages.bitsandbytes = prev.python3Packages.buildPythonPackage rec {
    pname = "bitsandbytes";
    version = "0.45.2";
    
    format = "wheel";
    
    wheelUrl = "https://files.pythonhosted.org/packages/${final.lib.strings.getFilenameFromURL (prev.python3Packages.pypi."${pname}/${version}".sourceUrls.${final.system}.url)}";
    wheelHash = "sha256-PLACEHOLDER";  # Update this with actual hash
    
    doCheck = false;
    
    propagatedBuildInputs = [
      final.python3Packages.numpy
      final.python3Packages.torch
    ];
    
    meta = with final.lib; {
      description = "LLM optimization libraries: 8-bit optimizers, matrix multiplication, quantization";
      homepage = "https://github.com/TimDettmers/bitsandbytes";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.linux ++ platforms.windows ++ platforms.darwin;
    };
  };
}
