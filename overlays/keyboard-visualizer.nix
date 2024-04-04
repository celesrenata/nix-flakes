final: prev:
rec {
  KeyboardVisualizer = prev.stdenv.mkDerivation {
    pname = "KeyboardVisualizer";
    version = "4.00";
    src = prev.fetchFromGitHub {
      owner = "CalcProgrammer1";
      repo = "KeyboardVisualizer";
      rev = "b50cc508f01fddfc2de9909c2611e75816ee444a";
      sha256 = "sha256-RJ7DN2Na35PaWa5hp7G37eZAIPsSi7otEmyU7vikQMs=";
      fetchSubmodules = true;
    };

    nativeBuildInputs = with prev.pkgs; [
      qt6.qmake
      openrgb
      qt6.qtwayland
      qt6.wrapQtAppsHook
      openal
    ];

    configurePhase = ''
      qmake KeyboardVisualizer.pro
    ''; 
    buildPhase = ''
      make -j8
    '';

    installPhase = ''
      install -m755 -D KeyboardVisualizer $out/bin/KeyboardVisualizer
    '';
  };
}