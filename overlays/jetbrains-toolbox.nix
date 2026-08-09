final: prev:

let
  pname = "jetbrains-toolbox";
  version = "3.6.2.85969";
  platform = prev.stdenv.hostPlatform.system;

  sources = {
    x86_64-linux = prev.fetchzip {
      url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${version}.tar.gz";
      sha256 = "sha256-1vVXHE4x2eq1LG1DoA/eeg5S4sA8sr/k5DhwD8+P6aE=";
      stripRoot = false;
    };
    aarch64-linux = prev.fetchzip {
      url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${version}-arm64.tar.gz";
      sha256 = "sha256-C0C4fng34YzdLugDBXwsH4H9ERkmI/FqWgUss92d6y0=";
      stripRoot = false;
    };
  };

  src = sources.${platform} or (throw "Unsupported platform: ${platform}");
  toolboxDir = "${src}/jetbrains-toolbox-${version}${if platform == "aarch64-linux" then "-arm64" else ""}";

in
{
  jetbrains-toolbox = prev.buildFHSEnv {
    inherit pname version;

    passthru = { inherit src; };

    multiPkgs = pkgs: with pkgs; [
      icu
      libappindicator-gtk3
    ] ++ prev.appimageTools.defaultFhsEnvArgs.multiPkgs pkgs;

    runScript = "${toolboxDir}/bin/jetbrains-toolbox --update-failed";

    extraInstallCommands = ''
      install -Dm0644 ${toolboxDir}/bin/jetbrains-toolbox.desktop -t $out/share/applications
      install -Dm0644 ${toolboxDir}/bin/toolbox.svg $out/share/icons/hicolor/scalable/apps/jetbrains-toolbox.svg
    '';

    meta = with prev.lib; {
      description = "JetBrains Toolbox";
      homepage = "https://jetbrains.com/";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" "aarch64-linux" ];
      mainProgram = pname;
    };
  };
}
