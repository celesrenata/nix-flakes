final: prev:

rec {
  jetbrains-toolbox-aarch64 = prev.stdenv.mkDerivation rec {
    pname = "jetbrains-toolbox";
    version = "2.5.4.38621";

    appimageContents = prev.runCommand "${pname}-extracted" {
      nativeBuildInputs = [prev.appimageTools.appimage-exec];
    } ''
        appimage-exec.sh -x $out ${src}/${pname}-${version}/${pname}

        # JetBrains ship a broken desktop file. Despite registering a custom scheme handler for jetbrains:// URLs, they never mark the command as being suitable for passing URLs to. Ergo, the handler never receives its payload. This causes various things to break, including login. Reported upstream at: https://youtrack.jetbrains.com/issue/TBX-11478/
        sed -Ei '/Exec/c\Exec=jetbrains-toolbox %U' $out/jetbrains-toolbox.desktop;
      '';

    src = prev.fetchzip {
      url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${version}-arm64.tar.gz";
      sha256 = "sha256-PRqzWLhZuIEdNYHAoutkmy3581zM5Riixnu0XRkmtnc=";
      stripRoot = false;
    };

    appimage = prev.appimageTools.wrapAppImage {
      inherit pname version;
      src = appimageContents;
    };

    nativeBuildInputs = [prev.makeWrapper prev.copyDesktopItems];
    buildInputs = [prev.jetbrains.jdk];

    installPhase = ''
      runHook preInstall;
      
      install -Dm644 ${../resources/icons/jetbrains-toolbox.svg} $out/share/icons/hicolor/scalable/apps/jetbrains-toolbox.svg
      makeWrapper ${appimage}/bin/${pname} $out/bin/${pname} --append-flags "--update-failed" --prefix LD_LIBRARY_PATH : ${prev.lib.makeLibraryPath [prev.icu]} --prefix MESA_EXTENSION_OVERRIDE : "-GL_ARB_invalidate_subdata" --set TOOLBOX_JDK "${prev.pkgs.jetbrains.jdk}" --set JETBRAINSCLIENT_JDK "${prev.pkgs.jetbrains.jdk.home}"
      
      runHook postInstall;
    '';

    desktopItems = ["${appimageContents}/jetbrains-toolbox.desktop"];
    
    # Disabling the tests, this seems to be very difficult to test this app.
    doCheck = false;

    meta = with prev.lib; {
      description = "Jetbrains Toolbox";
      homepage = "https://jetbrains.com/";
      license = licenses.unfree;
      maintainers = with maintainers; [AnatolyPopov];
      platforms = ["aarch64-linux"];
      mainProgram = "${pname}";
    };
  };
}
