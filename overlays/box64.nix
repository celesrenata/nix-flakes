final: prev:
rec {
  box64Override = prev.box64.overrideAttrs (old: {
    cmakeFlags = old.cmakeFlags ++ [ 
      "-D PAGE16K=1"
    ];
  });
}