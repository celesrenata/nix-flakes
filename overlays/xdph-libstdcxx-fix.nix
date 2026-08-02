# Fix GLIBCXX version mismatch in xdg-desktop-portal-hyprland
#
# Problem: XDPH and hyprutils are built with GCC 16 (stdenv14), but Qt6 is
# still on GCC 15. When the dynamic linker resolves libstdc++.so.6, it finds
# the GCC 15 version via Qt's RUNPATH before the GCC 16 version.
# hyprutils requires GLIBCXX_3.4.35 (only in GCC 16), causing the picker to crash.
#
# Fix: Wrap the portal and picker binaries to LD_PRELOAD the correct libstdc++.
# This ensures GCC 16's libstdc++ is loaded first regardless of RUNPATH ordering.
#
# This overlay can be removed once Qt6 and the Hyprland ecosystem use the same
# GCC version in nixpkgs (check: nix eval nixpkgs#qt6.qtbase.stdenv.cc.cc.version).

final: prev:

let
  gcc16Lib = prev.xdg-desktop-portal-hyprland.stdenv.cc.cc.lib;
in
{
  xdg-desktop-portal-hyprland = prev.xdg-desktop-portal-hyprland.overrideAttrs (oldAttrs: {
    postFixup = (oldAttrs.postFixup or "") + ''
      # Wrap the portal daemon to preload GCC 16 libstdc++
      wrapProgram $out/libexec/xdg-desktop-portal-hyprland \
        --set LD_PRELOAD "${gcc16Lib}/lib/libstdc++.so.6"

      # Wrap the share picker to preload GCC 16 libstdc++
      wrapProgram $out/bin/hyprland-share-picker \
        --set LD_PRELOAD "${gcc16Lib}/lib/libstdc++.so.6"
    '';

    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.makeWrapper ];
  });
}
