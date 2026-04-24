final: prev:
rec {
  tiny-dfr = prev.tiny-dfr.overrideAttrs (old: {
    # Patch temporarily removed — file was never committed
    # patches = [
    #   ../patches/tiny-dfr.config.toml.patch
    # ];
  });
}
