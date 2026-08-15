# Overlay Group Registry
# Exports named groups of overlay functions so that mkPkgs can select
# which overlays to apply to each package set.
#
# Usage:
#   overlayGroups = import ./overlays/default.nix { inherit inputs; };
#   overlayGroups.common ++ overlayGroups.desktop  # => list of overlay functions

{ inputs }:

{
  # Overlays needed by all hosts: OpenGL, Hyprland desktop base, keyboard visualizer, debugpy
  common = [
    (import ./ffmpeg-pin-8.nix)
    (import ./inline-snapshot-fix.nix)
    inputs.hyprland.overlays.hyprland-packages
    inputs.hyprland.overlays.hyprland-extras
    (import ./xdph-libstdcxx-fix.nix)
    (import ./ii-desktop-mcp.nix inputs)
    inputs.nixgl.overlay
    inputs.dots-hyprland.overlays.default
    (import ./keyboard-visualizer.nix)
    (import ./debugpy.nix)
    (import ./comfyui.nix)
    (import ./mkvtoolnix.nix)
    (import ./tidal-hifi.nix)
  ];

  # Desktop environment overlays: theming, emoji picker, calculator, DP-3 filter
  desktop = [
    (import ./materialyoucolor.nix)
    (import ./end-4-dots.nix)
    (import ./fuzzel-emoji.nix)
    (import ./wofi-calc.nix)
    (import ./dots-hyprland-dp3-filter.nix inputs)
  ];

  # Development tool overlays: Helm, JetBrains, LaTeX, static Nix, MCP servers
  development = [
    (import ./helmfile.nix)
    (import ./jetbrains-toolbox.nix)
    (import ./latex.nix)
    (import ./nix-static.nix)
    (import ./mcp-servers.nix)
  ];

  # Gaming overlays: Proton tweaks, VR, real SDL2
  gaming = [
    inputs.protontweaks.overlay
    (import ./wivrn-fix.nix)
    (import ./sdl2-real.nix { inherit inputs; })
  ];

  # AI/ML overlays: ComfyUI, vLLM, TensorRT, xformers binary, bitsandbytes
  ai = [
    # Use CUDA 13 for Blackwell SM120 native support
    (final: prev: { cudaPackages = prev.cudaPackages_13; })
    (import ./vllm.nix)
    (import ./tensorrt.nix)
    (import ./ollama.nix)
    (import ./xformers-bin-0_0_28_post3.nix)
    (import ./bitsandbytes.nix)
    (import ./distcc-builds.nix)
  ];
}
