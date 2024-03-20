self: super: {
  nextcloud-client = super.nextcloud-client.overrideAttrs (old: rec{
    version = "3.0.3";

    src = super.fetchFromGitHub {
      owner = "nextcloud";
      repo = "desktop";
      rev = "v3.0.3";
      sha256 = "0idh8i71jivdjjs2y62l22yl3qxwgcr0hf53dad587bzgkkkr223";
    };

    buildInputs = old.buildInputs ++ [
      super.qt5.qtquickcontrols2
      super.qt5.qtgraphicaleffects
    ];
  });
}
