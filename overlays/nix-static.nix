final: prev:
rec {
  nixStatic = prev.nixStatic.overrideAttrs (old: {
    buildPhase = ''
      ulimit -s unlimited
    '' + old.buildPhase;
  });
}
