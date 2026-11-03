{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.my.profiles.development.enable {
    # Development programs
    # NOTE: programs.ccache.enable is intentionally NOT used. The nixpkgs ccache
    # module creates a setgid security.wrappers.nix-ccache around a Perl script
    # (nix-ccache.pl), which the newer ensureWrapperIntegrity assertion rejects
    # ("not an ELF! This is a security risk."). We don't use that stats wrapper
    # or the packageNames overlay path anyway — our ccache usage is driven
    # directly from build overlays (ollama/vllm/distcc) via
    # CMAKE_*_COMPILER_LAUNCHER=ccache with a per-build CCACHE_DIR, so we only
    # need the ccache binary on PATH.
    programs.nh.enable = true;
    programs.java.enable = true;
    environment.systemPackages = with pkgs; [
      # Compilers and build tools
      gcc13
      ccache
      cmake
      meson
      ninja
      pkg-config

      # Language runtimes
      nodejs
      openjdk
      typescript

      # AI coding agents
      codex
      uv
      pipx

      # Nix tooling
      nil

      # Dev libraries
      glib.dev
      glib
      glibc.dev
      gobject-introspection.dev
      pango.dev
      harfbuzz.dev
      cairo.dev
      gdk-pixbuf.dev
      atk.dev
      libpulseaudio.dev

      # AWS tools
      awscli2
      aws-cdk-cli

      # Kubernetes tools
      k3s
      (wrapHelm pkgs.kubernetes-helm {
        plugins = with pkgs.kubernetes-helmPlugins; [
          helm-secrets
          helm-diff
          helm-s3
          helm-git
        ];
      })
      pkgs.kubernetes-helm
      pkgs.helmfile
      pkgs.kustomize
      pkgs.kompose
      kubevirt
      pkgs.krew
    ];
  };
}
