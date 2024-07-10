final: prev: {
  keyd = prev.keyd.overrideAttrs (oldAttrs: {
    patches = [
      
      #../patches/keyd.keys.c.patch
      #../patches/keyd.keys.h.patch
    ];
  });

}