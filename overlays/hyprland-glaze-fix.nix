# Fix Hyprland build with glaze >= 8.0.0
#
# Problem: Hyprland 0.56.1 CMakeLists.txt requires `find_package(glaze 7...<8)`,
# but nixpkgs-unstable bumped glaze to 8.0.0. The range `7...<8` is rejected by
# glaze 8's SameMajorVersion compatibility check (min major 7 ≠ package major 8).
# When find_package fails, CMake falls back to FetchContent which requires git
# (unavailable in Nix sandbox).
#
# Fix: Remove the version constraint entirely — Nix already ensures the correct
# glaze version is in buildInputs. The FetchContent fallback is also disabled.
# This overlay can be removed once Hyprland in nixpkgs is updated to support glaze 8.

final: prev:

{
  hyprland = prev.hyprland.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace CMakeLists.txt \
        --replace-fail 'find_package(glaze 7...<8 QUIET)' 'find_package(glaze QUIET)'
    '';
  });
}
