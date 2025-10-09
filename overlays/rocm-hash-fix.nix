final: prev: {
  hipblaslt = prev.hipblaslt.overrideAttrs (oldAttrs: {
    src = oldAttrs.src.overrideAttrs (srcAttrs: {
      outputHash = "sha256:10smpw0jhl4xvwqxlvcb2bfil85ilz2g11yhflnn7cnz0z617q57";
    });
  });
}
