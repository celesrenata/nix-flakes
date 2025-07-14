final: prev:
rec {
  gnome-pie = prev.buildNpmPackage {
    pname = "kando";
    version = "0.8.0";
    src = prev.fetchFromGitHub {
      owner = "kando-menu";
      repo = "kando";
      rev = "d7095a9a36520ae08a5563545f3bf4832af2ee87";
      sha256 = "sha256-G1yGPAOQhy7KwWGBiyEYbdMRorbrTiCtcwaRu/zk1tw=";
    };

    npmDepsHash = "sha256-R4LQBRNUkbnvni4+Ow4WjaHFulqBD9JCukmUoPGuagQ=";
    makeCacheWritable = true;
    nativeBuildInputs = with prev.pkgs; [
      nodePackages.nodejs
      cmake
    ];
    configurePhase = ''
      ln -s $node_modules node_modules
      #cp -r $node_modules node_modules
      #chmod +w node_modules
    '';
    buildPhase = ''
      export makeCacheWritable 
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
