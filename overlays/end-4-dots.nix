final: prev:
rec {
  end-4-dots = prev.stdenv.mkDerivation {
    pname = "end-4-dots";
    version = "0.1";
    src = prev.fetchFromGitHub {
      owner = "end-4";
      repo = "dots-hyprland";
      rev = "f4251b71e3bd3b076271f0e5baad842e68e8247a";
      sha256 = "sha256-1lN/ueXRmudCD4d/14ssOOw3FwAWCqlOH7LbgYa95DE=";
    };

    patches = [
      ../patches/ags.sideright.centermodules.configure.js.patch
      ../patches/applycolor.sh.patch
      ../patches/cheatsheet.data_keybinds.js.patch
      ../patches/cheatsheet.keybinds.js.patch
      ../patches/cheatsheet.main.js.patch
      ../patches/data_keyboardlayouts.js.patch
      ../patches/user_options.js.patch
      ../patches/sequences.txt.patch
      ../patches/system.js.patch
      ../patches/hypr.hyprland.conf.patch
      ../patches/hypr.custom.env.conf.patch
      ../patches/hypr.custom.execs.conf.patch
      ../patches/hypr.custom.keybinds.conf.patch
      ../patches/hypr.custom.general.conf.patch
      ../patches/fish.config.fish.patch
    ];
    
    installPhase = ''
      install -m755 -D .local/bin/fuzzel-emoji $out/.local/bin/fuzzel-emoji
      cd .config
      find ags -type f | grep -v "_material.scss" | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      find anyrun -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
      #find fish -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
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
