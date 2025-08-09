final: prev: {
  fuzzel-emoji = prev.stdenv.mkDerivation rec {
    pname = "fuzzel-emoji";
    version = "unstable-2024-01-01";
    
    src = prev.fetchFromGitHub {
      owner = "end-4";
      repo = "fuzzel-emoji";
      rev = "b52d556a1a41598ccedac127586841ae565d701a";
      sha256 = "sha256-W8KCh/ui694Qb8KpH3oWPnFMCnUc6xKFdgDOdMV7e/k=";
    };
    
    nativeBuildInputs = with prev; [ makeWrapper ];
    
    buildInputs = with prev; [ bash ];
    
    installPhase = ''
      mkdir -p $out/bin
      cp fuzzel-emoji $out/bin/
      chmod +x $out/bin/fuzzel-emoji
      
      # Wrap the script to ensure dependencies are available
      wrapProgram $out/bin/fuzzel-emoji \
        --prefix PATH : ${prev.lib.makeBinPath [ prev.fuzzel prev.wl-clipboard ]}
    '';
    
    meta = with prev.lib; {
      description = "Emoji picker for fuzzel";
      homepage = "https://github.com/end-4/fuzzel-emoji";
      license = licenses.gpl3;
      platforms = platforms.linux;
      maintainers = [ ];
    };
  };
}
