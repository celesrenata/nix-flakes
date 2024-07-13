final: prev:
rec {
  tiny-dfr = prev.tiny-dfr.overrideAttrs (old: {
    patches = [
      ../patches/tiny-dfr.config.toml.patch
    ];
  });
}
