final: prev: {
  clblast = prev.clblast.overrideAttrs (oldAttrs: {
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    ];
  });
  
  # Test overlay application by renaming ollama
  ollama-fixed = prev.ollama;
  ollama = throw "ollama has been renamed to ollama-fixed to test overlay application";
}
