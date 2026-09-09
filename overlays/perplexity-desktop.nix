# Perplexity AI Desktop App
#
# Electron wrapper around https://www.perplexity.ai, packaged as a native-feeling
# desktop application with a .desktop launcher entry. Adapted from the upstream
# standalone flake into an overlay so it participates in the normal Nix build
# (no extra flake input required — it only depends on pkgs.electron + makeWrapper).
final: prev: {
  perplexity-desktop = prev.stdenv.mkDerivation rec {
    pname = "perplexity-desktop";
    version = "1.0.0";

    nativeBuildInputs = [ prev.makeWrapper ];

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/share/applications

      # Executable wrapper: launch Electron pointed at the Perplexity web app
      makeWrapper ${prev.electron}/bin/electron $out/bin/perplexity-desktop \
        --add-flags "--app=https://www.perplexity.ai" \
        --add-flags "--name=Perplexity"

      # Desktop entry
      cat > $out/share/applications/perplexity-desktop.desktop <<EOF
      [Desktop Entry]
      Name=Perplexity AI
      Exec=$out/bin/perplexity-desktop
      Icon=network-workgroup
      Type=Application
      Categories=Network;WebBrowser;Utility;
      Comment=Perplexity AI Desktop App Wrapper
      EOF
    '';

    meta = with prev.lib; {
      description = "Perplexity AI desktop app wrapper (Electron)";
      homepage = "https://www.perplexity.ai";
      license = licenses.unfree;
      platforms = platforms.linux;
      mainProgram = "perplexity-desktop";
    };
  };
}
