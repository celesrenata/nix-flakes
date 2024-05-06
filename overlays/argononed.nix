final: prev:
let
    argononed = fetchGit {
      url = "https://gitlab.com/DarkElvenAngel/argononed.git";
      ref = "master"; # Or any other branches deemed suitable
    };
in
rec {
  argononedOverride = argononed.overrideAttrs (old: {
    patches = [
      "OS/nixos/patches/shutdown.patch"
    ];
  });
}