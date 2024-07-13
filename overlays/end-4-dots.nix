final: prev:
rec {
  end-4-dots = prev.stdenv.mkDerivation {
    pname = "end-4-dots";
    version = "0.1";
    src = prev.fetchFromGitHub {
      owner = "celesrenata";
      repo = "dots-hyprland";
      rev = "f2e0d797e65656044b0b804541d1cd14eadc37e4";
      sha256 = "sha256-xD5mVe4+hwwmuaMKVRfeo9J+alS3W+PE/l1p90F1K3I=";
    };

    installPhase = ''
      install -m755 -D .local/bin/fuzzel-emoji $out/.local/bin/fuzzel-emoji
      install -m755 -D .local/bin/initialSetup.sh $out/.local/bin/initialSetup.sh
      cd .config
      find ags -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find anyrun -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find fish -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find foot -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      #find fontconfig -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find hypr -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find mpv -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find qt5ct -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find wlogout -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find zshrc.d -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      install -m755 -D starship.toml $out/.config/starship.toml
      install -m755 -D thorium-flags.conf $out/.config/thorium-flags.conf
    '';
  };
}
