# final: prev:
# rec {
#   wofi-calc-init = prev.stdenv.override {
#     packageOverrides = final: prev:
#       wofi-calc = prev.stdenv.mkDerivation {
#         pname = "wofi-calc";
#         version = "1.1";
#         src =  pkgs.fetchFromGitHub {
#           owner = "Zeioth";
#           repo = "wofi-calc";
#           rev = "edd316f3f40a6fcb2afadf5b6d9b14cc75a901e0";
#           sha256 = "sha256-y8GoTHm0zPkeXhYS/enNAIrU+RhrUMnQ41MdHWWTPas=";
#         };

#         installPhase = ''
#           install -m755 -D wofi-calc.sh $out/bin/wofi-calc
#         '';
#       };
#   };
  
#   wofi-calc = wofi-calc-init.pkgs.mkDerivation rec {
#     pname = "wofi-calc";
#     version = "1.1";
#     src =  pkgs.fetchFromGitHub {
#       owner = "Zeioth";
#       repo = "wofi-calc";
#       rev = "edd316f3f40a6fcb2afadf5b6d9b14cc75a901e0";
#       sha256 = "sha256-y8GoTHm0zPkeXhYS/enNAIrU+RhrUMnQ41MdHWWTPas=";
#     };

#     installPhase = ''
#       install -m755 -D wofi-calc.sh $out/bin/wofi-calc
#     '';
#   };
# }

final: prev:
rec {
  wofi-calc = prev.stdenv.mkDerivation {
    pname = "wofi-calc";
    version = "1.1";
    src =  prev.fetchFromGitHub {
      owner = "Zeioth";
      repo = "wofi-calc";
      rev = "edd316f3f40a6fcb2afadf5b6d9b14cc75a901e0";
      sha256 = "sha256-y8GoTHm0zPkeXhYS/enNAIrU+RhrUMnQ41MdHWWTPas=";
    };

    installPhase = ''
      install -m755 -D wofi-calc.sh $out/bin/wofi-calc
    '';
  };
}
