final: prev:
rec {
  end-4-dots = prev.stdenv.mkDerivation {
    pname = "end-4-dots";
    version = "0.1";
    src = prev.fetchFromGitHub {
      owner = "end-4";
      repo = "dots-hyprland";
      rev = "0d3fc19e572c69ecfc87d606c7f291c67315dae1";
      sha256 = "sha256-LgBSN0PBhnvl/BfEQt80ClQBsdF2zhPPQcJORusgUVU=";
    };

    patches = (prev.patches or []) ++ [
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/applycolor.sh.patch";
        hash = "sha256-kltBCtkmxQeiCXAAZiuzQMHw2WwS02BSSaF6IME33ms=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/cheatsheet.data_keybinds.js.patch";
        hash = "sha256-zLCfjGJY0Acs4vDUnHsW+xClF3Z2jq5EE50pFP4lEHM=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/cheatsheet.main.js.patch";
        hash = "sha256-emI+7p0Vmb3Unht9vH/YqCJ+EMyhUMhj+XcLcM1GyMA";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/data_keyboardlayouts.js.patch";
        hash = "sha256-5u1urGWxs66/e3dqlYWu9tjHKmM45JkWexhYjRVdXrY=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/system.js.patch";
        hash = "sha256-Lp71lv6RSEpgEw21m8mjWSVU7XYXpQgcd95rFaAhaG4=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/hypr.hyprland.conf.patch";
        hash = "sha256-y8kkpWmF7Z4oYX1pz35lLKMqegD6pM++/Tqbc9VIBMg=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/hypr.custom.execs.conf.patch";
        hash = "sha256-j2sWmiX1ymQ4U6GDAJ8qUofO3QgzeQbpbrKvCcnsBv4=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/hypr.custom.keybinds.conf.patch";
        hash = "sha256-Q/7cT2O3OJK5XtlG30tLT6GKisD357F8N8D3h8Tjrqg=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/hypr.custom.general.conf.patch";
        hash = "sha256-1B138v++TXzsK0pdL83XMIaIPM3xlf7YSeSDQT0/34E=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/hypr.hyprland.general.conf.patch";
        hash = "sha256-9hv5ZeUzMtER4Q39kMBIoQ3xuRNFl9B239fGhjgoANc=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/fish.config.fish.patch";
        hash = "sha256-118vYJHSRHZ8g1zqXyrTJMR631i6QoJMoNZoQg5ZAE0=";
      })

    ];
    installPhase = ''
      cd .config
      find ags -type f | grep -v "_material.scss" | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find anyrun -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find fish -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      #find fontconfig -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find hypr -type f | grep -v "hyprlock.conf\|colors.conf" | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find mpv -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find qt5ct -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find wlogout -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find zshrc.d -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      install -m755 -D starship.toml $out/.config/starship.toml
      install -m755 -D thorium-flags.conf $out/.config/thorium-flags.conf
    '';
  };
}
