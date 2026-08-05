# Overlay: Real SDL2 (not sdl2-compat)
#
# nixpkgs unstable replaced SDL2 with sdl2-compat (an SDL3-based shim).
# OldUnreal's Unreal Tournament crashes with "Inconsistent SDL window flags"
# when using sdl2-compat. This overlay pulls the real SDL2 from nixos-24.11.
{ inputs }:
final: prev:
let
  pkgs-24_11 = import inputs.nixpkgs-24_11 {
    system = prev.stdenv.hostPlatform.system;
    config = { allowUnfree = true; };
  };
in
{
  sdl2-real = pkgs-24_11.SDL2;
}
