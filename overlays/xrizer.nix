# XRizer Overlay - Update to 0.4 for VR support
# Provides an updated version of xrizer for virtual reality applications

final: prev: {
  python3Packages.xrizer = prev.python3Packages.buildPythonPackage rec {
    pname = "xrizer";
    version = "0.4.1";
    
    format = "wheel";
    
    wheelUrl = "https://files.pythonhosted.org/packages/${final.lib.strings.getFilenameFromURL (prev.python3Packages.pypi."${pname}/${version}".sourceUrls.${final.system}.url)}";
    wheelHash = "sha256-PLACEHOLDER";  # Update with actual hash
    
    doCheck = false;
    
    propagatedBuildInputs = [
      final.python3Packages.pygame
      final.python3Packages.glfw
      final.python3Packages.numpy
    ];
    
    meta = with final.lib; {
      description = "XRizer: OpenXR runtime for virtual reality applications";
      homepage = "https://github.com/immersive-collaboration/xrizer";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.linux ++ platforms.windows ++ platforms.darwin;
    };
  };
}
