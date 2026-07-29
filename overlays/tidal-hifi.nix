# Electron 41/Chrome 146 + kernel 7.1 has a faccessat2/shm regression
# that causes ESRCH on /dev/shm access checks in the zygote subprocess.
# Work around by passing --no-sandbox at the wrapper level.
final: prev: {
  tidal-hifi = prev.tidal-hifi.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/tidal-hifi \
        --add-flags "--no-sandbox"
    '';
  });
}
