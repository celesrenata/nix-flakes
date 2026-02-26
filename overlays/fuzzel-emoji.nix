final: prev: {
  fuzzel-emoji = prev.stdenv.mkDerivation rec {
    pname = "fuzzel-emoji";
    version = "unstable-2024-01-01";
    
    src = prev.fetchFromGitHub {
      owner = "end-4";
      repo = "fuzzel-emoji";
      rev = "c1914cf9bb06300bc8be35c1829296afbe452241";
      sha256 = "sha256-QeXRKSNlT4m7CX5qoZw/EH3Z6B3DSg+gc2SK89hBeek=";
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
