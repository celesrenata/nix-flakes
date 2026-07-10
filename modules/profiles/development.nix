{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.my.profiles.development.enable {
    # Development programs
    programs.ccache.enable = true;
    programs.nh.enable = true;
    programs.java.enable = true;
    environment.systemPackages = with pkgs; [
      # Compilers and build tools
      gcc13
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
