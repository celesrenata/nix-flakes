final: prev:
rec {
  end-4-dots = prev.stdenv.mkDerivation {
    pname = "end-4-dots";
    version = "0.1";
    src = prev.fetchFromGitHub {
      owner = "end-4";
      repo = "dots-hyprland";
      rev = "ffbd6d1e4df7811a0eeb8884ba390eb9d1e2fad6";
      sha256 = "sha256-R2xDSGZQ64+D1eQfxtW8s4jJiDD9z57qOwSW+qsuXTU=";
    };

    patches = (prev.patches or []) ++ [
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/applycolor.sh.patch";
        hash = "sha256-5zRF4VuRXg3v3ePXVgQbdEZkMcMg5wBvTz8BP8cZByA=";
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
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/hyprland.conf.patch";
        hash = "sha256-ANmOuJMjTP58a1SbnHTuDheeq8/WxKJ9YyX+7UO+3s4=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/hypr.execs.conf.patch";
        hash = "sha256-/52kJyTLXVjYhCel/ZlNXMNBucPBeMBy6Wl1UXygT1s=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/hypr.keybinds.conf.patch";
        hash = "sha256-Bu+Df1TCxQWiwVJ1BcjFtsSFO3WGgYs78VmqLbhiKvE=";
      })
      (prev.fetchpatch {
        url = "https://raw.githubusercontent.com/celesrenata/dotfiles/nix-patches/hypr.general.conf.patch";
        hash = "sha256-lUM0fM5dbgbAtH6v9Avz3s1thoO5FpVwAF3qb//4cQc=";
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
      install -m755 -D starship.toml $out/starship.toml
      install -m755 -D thorium-flags.conf $out/thorium-flags.conf
    '';
  };
}