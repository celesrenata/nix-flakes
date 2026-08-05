final: prev:

let
  version = "3.6.2.85969";
  platform = prev.stdenv.hostPlatform.system;

  sources = {
    x86_64-linux = {
      url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${version}.tar.gz";
      sha256 = "sha256-1vVXHE4x2eq1LG1DoA/eeg5S4sA8sr/k5DhwD8+P6aE=";
    };
    aarch64-linux = {
      url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${version}-arm64.tar.gz";
      sha256 = "sha256-C0C4fng34YzdLugDBXwsH4H9ERkmI/FqWgUss92d6y0=";
    };
  };

  # x86_64: regular ELF binary in tarball (no longer AppImage as of 3.6.x)
  mkToolbox-x86 = prev.stdenv.mkDerivation rec {
    pname = "jetbrains-toolbox";
    inherit version;

    src = prev.fetchzip {
      inherit (sources.x86_64-linux) url sha256;
      stripRoot = false;
    };

    nativeBuildInputs = [ prev.makeWrapper prev.autoPatchelfHook prev.copyDesktopItems ];
    buildInputs = with prev; [ stdenv.cc.cc.lib libGL libx11 libxi libxrender libxtst fontconfig freetype icu libXScrnSaver libxcb ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib $out/share/icons/hicolor/scalable/apps

      # Copy the binary and libraries
      cp ${src}/${pname}-${version}/bin/${pname} $out/bin/${pname}-unwrapped
      cp ${src}/${pname}-${version}/bin/*.so* $out/lib/ 2>/dev/null || true

      # Icon
      install -Dm644 ${src}/${pname}-${version}/bin/toolbox.svg $out/share/icons/hicolor/scalable/apps/jetbrains-toolbox.svg

      # Wrapper
      makeWrapper $out/bin/${pname}-unwrapped $out/bin/${pname} \
        --append-flags "--update-failed" \
        --prefix LD_LIBRARY_PATH : "$out/lib:${prev.lib.makeLibraryPath [ prev.icu prev.libGL prev.libx11 prev.libXScrnSaver prev.libxcb ]}" \
        --prefix MESA_EXTENSION_OVERRIDE : "-GL_ARB_invalidate_subdata" \
        --set TOOLBOX_JDK "${prev.pkgs.jetbrains.jdk}" \
        --set JETBRAINSCLIENT_JDK "${prev.pkgs.jetbrains.jdk.home}"

      runHook postInstall
    '';

    desktopItems = [
      (prev.makeDesktopItem {
        name = "jetbrains-toolbox";
        desktopName = "JetBrains Toolbox";
        exec = "jetbrains-toolbox %U";
        icon = "jetbrains-toolbox";
        comment = "Manage JetBrains tools";
        categories = [ "Development" ];
        startupWMClass = "jetbrains-toolbox";
      })
    ];
    doCheck = false;

    meta = with prev.lib; {
      description = "JetBrains Toolbox";
      homepage = "https://jetbrains.com/";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
      mainProgram = pname;
    };
  };

  # aarch64: regular ELF binary in tarball
  mkToolbox-aarch64 = prev.stdenv.mkDerivation rec {
    pname = "jetbrains-toolbox";
    inherit version;

    src = prev.fetchzip {
      inherit (sources.aarch64-linux) url sha256;
      stripRoot = false;
    };

    nativeBuildInputs = [ prev.makeWrapper prev.autoPatchelfHook prev.copyDesktopItems ];
    buildInputs = with prev; [ stdenv.cc.cc.lib libGL libx11 libxi libxrender libxtst fontconfig freetype icu ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin $out/lib $out/share/icons/hicolor/scalable/apps

      # Copy the binary and libraries
      cp ${src}/${pname}-${version}-arm64/bin/${pname} $out/bin/${pname}-unwrapped
      cp ${src}/${pname}-${version}-arm64/bin/*.so* $out/lib/ 2>/dev/null || true

      # Icon and desktop file
      install -Dm644 ${src}/${pname}-${version}-arm64/bin/toolbox.svg $out/share/icons/hicolor/scalable/apps/jetbrains-toolbox.svg
      install -Dm644 ${src}/${pname}-${version}-arm64/bin/${pname}.desktop $out/share/applications/${pname}.desktop
      sed -i "s|Exec=.*|Exec=jetbrains-toolbox %U|" $out/share/applications/${pname}.desktop

      # Wrapper
      makeWrapper $out/bin/${pname}-unwrapped $out/bin/${pname} \
        --append-flags "--update-failed" \
        --prefix LD_LIBRARY_PATH : "$out/lib:${prev.lib.makeLibraryPath [ prev.icu prev.libGL prev.libx11 ]}" \
        --prefix MESA_EXTENSION_OVERRIDE : "-GL_ARB_invalidate_subdata"

      runHook postInstall
    '';

    doCheck = false;

    meta = with prev.lib; {
      description = "JetBrains Toolbox";
      homepage = "https://jetbrains.com/";
      license = licenses.unfree;
      platforms = [ "aarch64-linux" ];
      mainProgram = pname;
    };
  };

in
{
  jetbrains-toolbox = if platform == "aarch64-linux" then mkToolbox-aarch64 else mkToolbox-x86;
}
