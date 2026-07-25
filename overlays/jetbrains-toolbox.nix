final: prev:

let
  version = "3.6.2.85969";
  platform = prev.stdenv.hostPlatform.system;

  sources = {
    x86_64-linux = {
      url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${version}.tar.gz";
      sha256 = "sha256-S4B7semtrNK56mbfUOapYuFTPX1VKNULIm8yY2ojn8M=";
    };
    aarch64-linux = {
      url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${version}-arm64.tar.gz";
      sha256 = "sha256-C0C4fng34YzdLugDBXwsH4H9ERkmI/FqWgUss92d6y0=";
    };
  };

  # x86_64: AppImage-based packaging
  mkToolbox-x86 = prev.stdenv.mkDerivation rec {
    pname = "jetbrains-toolbox";
    inherit version;

    src = prev.fetchzip {
      inherit (sources.x86_64-linux) url sha256;
      stripRoot = false;
    };

    appimageContents = prev.runCommand "${pname}-extracted" {
      nativeBuildInputs = [ prev.appimageTools.appimage-exec ];
    } ''
      appimage-exec.sh -x $out ${src}/${pname}-${version}/${pname}
      sed -Ei '/Exec/c\Exec=jetbrains-toolbox %U' $out/jetbrains-toolbox.desktop;
    '';

    appimage = prev.appimageTools.wrapAppImage {
      inherit pname version;
      src = appimageContents;
    };

    nativeBuildInputs = [ prev.makeWrapper prev.copyDesktopItems ];
    buildInputs = [ prev.jetbrains.jdk ];

    installPhase = ''
      runHook preInstall
      install -Dm644 ${../resources/icons/jetbrains-toolbox.svg} $out/share/icons/hicolor/scalable/apps/jetbrains-toolbox.svg
      makeWrapper ${appimage}/bin/${pname} $out/bin/${pname} \
        --append-flags "--update-failed" \
        --prefix LD_LIBRARY_PATH : ${prev.lib.makeLibraryPath [ prev.icu ]} \
        --prefix MESA_EXTENSION_OVERRIDE : "-GL_ARB_invalidate_subdata" \
        --set TOOLBOX_JDK "${prev.pkgs.jetbrains.jdk}" \
        --set JETBRAINSCLIENT_JDK "${prev.pkgs.jetbrains.jdk.home}"
      runHook postInstall
    '';

    desktopItems = [ "${appimageContents}/jetbrains-toolbox.desktop" ];
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
    buildInputs = with prev; [ stdenv.cc.cc.lib libGL xorg.libX11 xorg.libXi xorg.libXrender xorg.libXtst fontconfig freetype icu ];

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
        --prefix LD_LIBRARY_PATH : "$out/lib:${prev.lib.makeLibraryPath [ prev.icu prev.libGL prev.xorg.libX11 ]}" \
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
