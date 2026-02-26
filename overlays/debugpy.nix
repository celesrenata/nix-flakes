final: prev: {
  debugpy-notests = prev.python3Packages.debugpy.overrideAttrs (oldAttrs: {
    pytestCheckPhase = "true";
  });
}