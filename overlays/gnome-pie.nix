final: prev:
rec {
  gnome-pie = prev.stdenv.mkDerivation {
    pname = "gnome-pie";
    version = "0.7.3";
    src = prev.fetchFromGitHub {
      owner = "Schneegans";
      repo = "Gnome-Pie";
      rev = "0140a404f37d33dea074e8c134c82e47f56c5ece";
      sha256 = "sha256-ySV4tBoHLK8B24yOok6VKdGiqXmwSFYE351FfvSlyrg=";
    };

    nativeBuildInputs = with prev.pkgs; [
      cmake
      gnome-menus
      gtk3
      libappindicator
      libarchive.dev
      libdatrie.dev
      libepoxy.dev
      libgee
      libselinux.dev
      libsepol
      libstartup_notification
      libthai.dev
      libwnck.dev
      libxkbcommon.dev
      libxml2.dev
      pcre2
      pkg-config
      util-linux.dev
      vala
      xorg.libXdmcp
      xorg.libXres
      xorg.libXtst
      wrapGAppsHook
    ];
    configurePhase = ''
      mkdir build
      cd build
      cmake ..
    '';
    buildPhase = ''
      make -j8
      cd .. 
    '';

    installPhase = ''
      find resources/ | awk '{ print "install -m755 -D " $0 " \$out/bin/" $0 }' | bash
      install -m755 -D gnome-pie $out/bin/gnome-pie
    '';
  };
}