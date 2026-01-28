final: prev:
let
  lib = prev.lib;
in {
  xrizer = prev.xrizer.overrideAttrs (old: rec {
    version = "0.4";

    src = prev.fetchFromGitHub {
      owner = "Supreeeme";
      repo  = "xrizer";
      rev   = "v${version}";
      hash  = "sha256-IRhLWlGHywp0kZe5aGmMHAF1zZwva3sGg68eG1E2K9A=";
    };

    # Drop the nixpkgs patch that was needed for 0.3 but conflicts with 0.4
    patches = builtins.filter
      (p: !(lib.hasInfix "xrizer-fix-flaky-tests.patch" (toString p)))
      (old.patches or []);

    # IMPORTANT: xrizer in nixpkgs is using vendored cargo deps.
    # When you bump src, you must bump the vendor hash too.
    cargoDeps = prev.rustPlatform.fetchCargoVendor {
      inherit src;
      hash = "sha256-orfK5pwWv91hA7Ra3Kk+isFTR+qMHSZ0EYZTVbf0fO0=";
    };
  });
}

