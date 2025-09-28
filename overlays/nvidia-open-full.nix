self: super: {
  linuxPackages_latest = super.linuxPackages_latest.extend (kernelFinal: kernelPrev: {
    nvidia_x11 = kernelPrev.nvidia_x11.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ self.pkg-config ];
      buildInputs = (old.buildInputs or []) ++ [ self.gtk3 self.gtk2 ];
      postPatch = ''
        echo "Added pkg-config and GTK" > $out/patched.txt
      '';
    });
  });
}
