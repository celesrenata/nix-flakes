final: prev:
rec {
  gnome-network-displaysOverride = prev.gnome-network-displays.overrideAttrs (old: {

    buildInputs = old.buildInputs ++ [
      prev.glib-networking
    ];
  });
}
