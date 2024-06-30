final: prev:
{
  jetbrains-toolbox = prev.jetbrains-toolbox.overrideAttrs (prev: rec {
    pname = "jetbrains-toolbox";
    version = "2.3.2.31487";
    src = prev.fetchzip {
      url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${version}-arm64.tar.gz";
      sha256 = "sha256-mrTeUp9DBSO1S6Nxx077lqtY847CiCBCCi/vboZ8ADs=";
      stripRoot = false;
    };
    meta = with prev.lib; {
      description = "Jetbrains Toolbox";
      homepage = "https://jetbrains.com/";
      license = licenses.unfree;
      maintainers = with maintainers; [AnatolyPopov];
      platforms = ["aarch64-linux"];
      mainProgram = "${pname}";
    };
  });
}
