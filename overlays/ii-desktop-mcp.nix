# Override ii-desktop-mcp to use our patched Hyprland
#
# Problem: The ii-desktop-mcp flake evaluates its package using
# nixpkgs.legacyPackages (without overlays), which pulls in the
# broken unpatched Hyprland.
#
# Fix: Re-build ii-desktop-mcp with our overlay-patched pkgs.
# This overlay can be removed once the Hyprland/glaze issue is fixed upstream.

inputs:

final: prev:

{
  ii-desktop-mcp = import "${inputs.ii-desktop-mcp}/nix/package.nix" {
    pkgs = final;
    src = inputs.ii-desktop-mcp;
  };
}
