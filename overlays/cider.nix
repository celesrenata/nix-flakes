final: prev: {
  cider = prev.cider.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      substituteInPlace $out/share/applications/cider.desktop \
        --replace "cider --no-sandbox %U" "env -u NIXOS_OZONE_WL cider --use-gl=desktop %U"
    '';
  });
}