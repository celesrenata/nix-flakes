(final: prev: {
  nvidia-open = prev.nvidia-open.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.pkg-config ];
    buildInputs = (old.buildInputs or []) ++ [ final.gtk3 final.gtk2 ];
    postPatch = (old.postPatch or "") + ''
      echo "#### OVERRIDE HIT: nvidia-open $(which pkg-config || true)"
    '';
  });
  linuxPackages_latest = prev.linuxPackages_latest // {
    nvidia-open = prev.linuxPackages_latest.nvidia-open.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.pkg-config ];
      buildInputs = (old.buildInputs or []) ++ [ final.gtk3 final.gtk2 ];
      postPatch = (old.postPatch or "") + ''
        echo "#### OVERRIDE HIT: nvidia-open in linuxPackages_latest $(which pkg-config || true)"
      '';
    });
  };
})
