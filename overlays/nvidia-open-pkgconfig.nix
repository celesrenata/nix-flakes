final: prev: {
  nvidia-open = prev.nvidia-open.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.pkg-config ];
    buildInputs = (old.buildInputs or []) ++ [ final.gtk3 final.gtk2 ];
  });
  nvidia-open-kernel-module = prev.nvidia-open-kernel-module.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.pkg-config ];
    buildInputs = (old.buildInputs or []) ++ [ final.gtk3 final.gtk2 ];
  });
  nvidiaPackages = prev.nvidiaPackages // {
    stable = prev.nvidiaPackages.stable // {
      open = prev.nvidiaPackages.stable.open.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.pkg-config ];
        buildInputs = (old.buildInputs or []) ++ [ final.gtk3 final.gtk2 ];
      });
    };
  };
  linuxPackages_6_15 = prev.linuxPackages_6_15 // {
    nvidia-open = prev.linuxPackages_6_15.nvidia-open.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.pkg-config ];
      buildInputs = (old.buildInputs or []) ++ [ final.gtk3 final.gtk2 ];
    });
  };
}

