# Development profile for Nigel
# Compilers, build tools, language runtimes
# Lightweight: no K8s tools, no heavy ML frameworks

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.my.profiles.development.enable {
    # NOTE: programs.ccache.enable intentionally omitted — the nixpkgs ccache
    # module wraps a Perl script (nix-ccache.pl) via setgid security.wrappers,
    # which ensureWrapperIntegrity now rejects as a non-ELF wrapper. We only
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

      # AWS tools — lightweight, no K8s
      awscli2
    ];
  };
}
