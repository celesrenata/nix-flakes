final: prev:
rec {
  latexRes-package = prev.stdenv.mkDerivation rec {
    name = "latexRes";
    src = prev.fetchFromGitHub {
      owner = "ChrisDienes";
      repo = "latex_resume";
      rev = "bd4a777613e0d04463990a5b207917feb866d4dd";
      sha256 = "sha256-K6HTXs+rkB1FayxfzLjZytOZT40a9Jipz8B3AC9LPxI=";
    };
    installPhase = ''
      mkdir -p $out/tex/latex
      cp res.cls $out/tex/latex/res.cls
    '';
    pname = name;
    tlType = "run";
  };
  tex = prev.texlive.combine {
    inherit (prev.texlive) scheme-full;
    latexRes-package = {
      pkgs = [ latexRes-package ];
    };
  };
}
