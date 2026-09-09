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
    (import ./perplexity-desktop.nix)
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
    # Use CUDA 13 for Blackwell SM120 native support.
    #
    # cuda_compat is a driver forward-compat shim. In this nixpkgs pin the
    # CUDA 13.2 redist manifest lists a linux-x86_64 cuda_compat tarball, but
    # the derivation is mis-gated (meta.platforms = []) and its src is unwired,
    # so it fails to build ("variable $src should point to the source") and
    # poisons the entire 13.2 closure (cuda_cudart propagates it). cuda_compat
    # only matters for running newer-CUDA binaries against an OLDER driver;
    # esnixi runs a current NVIDIA 580 driver, so it is unnecessary here.
    # Replace it with an empty output that satisfies the cuda-compat runpath
    # hook without a source, keeping the intended CUDA 13 stack buildable.
    (final: prev:
      {
        cudaPackages = prev.cudaPackages_13.overrideScope (cudaFinal: cudaPrev: {
          cuda_compat = prev.runCommand "cuda_compat-stub-595.58.03" {
            meta = (cudaPrev.cuda_compat.meta or {}) // {
              platforms = [ "x86_64-linux" ];
              broken = false;
            };
          } ''
            mkdir -p "$out/lib"
          '';
        });
      })
    (import ./vllm.nix)
    (import ./tensorrt.nix)
    (import ./ollama.nix)
    (import ./xformers-bin-0_0_28_post3.nix)
    (import ./bitsandbytes.nix)
    (import ./distcc-builds.nix)
  ];
}
