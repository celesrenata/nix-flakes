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
    (import ./freerdp.nix)
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

          # CCCL 13.3.3.4.1: drop the "fix-invalid-cpp-syntax" patch (backport of
          # NVIDIA/cccl PR #8771). The 13.3.3 redist source already contains that
          # fix, so applying it fails with "Reversed (or previously applied) patch
          # detected!" and aborts the build. This nixpkgs pin mis-gates the patch
          # as `cudaAtLeast "13.2" && cudaOlder "13.4"` (it should stop at 13.3).
          # Upstream fixed this in nixpkgs commit b01001ac7e20
          # ("cudaPackages_13_3.cccl: don't patch 13.3+", 2026-09-22), which has
          # not yet reached the nixos-unstable channel. Reproduce that fix locally
          # by stripping the redundant patch. Remove this override once the pinned
          # nixpkgs advances past b01001ac7e20.
          cccl = cudaPrev.cccl.overrideAttrs (old: {
            patches = builtins.filter
              (p: !(prev.lib.hasInfix "fix-invalid-cpp-syntax" (p.name or "")))
              (old.patches or []);
          });

          # NCCL 2.32.3-1: correct a stale source hash. nixpkgs (including
          # master) pins the NVIDIA/nccl v2.32.3-1 tag tarball at
          # sha256-ytAJn8F0QEHhUadiOmVKTUiL7lsUnasoP4MOv/t60xk=, but GitHub now
          # serves a different archive for that tag (NVIDIA re-tagged / the
          # auto-generated tarball changed), so the fixed-output fetch fails with
          # a hash mismatch. Verified the CURRENT correct hash by independent
          # `nix-prefetch-url --unpack` of
          # https://github.com/NVIDIA/nccl/archive/refs/tags/v2.32.3-1.tar.gz
          # -> sha256-xUllfdWAL0Ee9P9T9CZC2ddkPRnSXZXgwApgO398i6g= (matches the
          # "got" value from the failing build). Override the fetched src hash to
          # the real one. Remove this once nixpkgs updates the upstream pin.
          nccl = cudaPrev.nccl.overrideAttrs (old: {
            src = old.src.overrideAttrs (_: {
              outputHash = "sha256-xUllfdWAL0Ee9P9T9CZC2ddkPRnSXZXgwApgO398i6g=";
            });
          });
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
