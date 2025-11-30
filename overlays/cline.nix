final: prev: {
  cline = prev.buildNpmPackage rec {
    pname = "cline";
    version = "1.0.1";

    src = prev.fetchFromGitHub {
      owner = "cline";
      repo = "cline";
      rev = "v${version}";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will need to be updated
    };

    npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will need to be updated

    meta = with prev.lib; {
      description = "Autonomous coding agent right in your IDE, capable of creating/editing files, executing commands, and more with your permission every step of the way";
      homepage = "https://github.com/cline/cline";
      license = licenses.asl20;
      maintainers = [ ];
      platforms = platforms.all;
    };
  };
}
