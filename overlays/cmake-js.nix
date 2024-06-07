final: prev:
rec {
  gnome-pie = prev.buildNpmPackage {
    pname = "cmake-js";
    version = "7.0.0";
    src = prev.fetchFromGitHub {
      owner = "cmake-js";
      repo = "cmake-js";
      rev = "110c5637119bac684aa70fbcde561f7d2ce1850d";
      sha256 = "sha256-bYFi0/2g3etfJZUfK0IOykWiPgy+Qr69rBeYxuRtSqY=";
    };

    npmDepsHash = "sha256-R4LQBRNUkbnvni4+Ow4WjAHFulqBD9JCukmUoPGuagQ=";
    makeCacheWritable = true;
    nativeBuildInputs = with prev.pkgs; [
      cmake
    ];
    configurePhase = ''
      ln -s $node_modules node_modules
    '';
    buildPhase = ''
      export HOME=$(mktemp -d)
      yarn --offline build 
    '';

    distPhase = "true";

    installPhase = ''
      find resources/ | awk '{ print "install -m755 -D " $0 " \$out/bin/" $0 }' | bash
      install -m755 -D gnome-pie $out/bin/gnome-pie
    '';
  };
}
