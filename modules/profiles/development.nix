{ config, lib, pkgs, pkgs-unstable, ... }:

{
  config = lib.mkIf config.my.profiles.development.enable {
    # Development programs
    programs.ccache.enable = true;
    programs.nh.enable = true;
    programs.java.enable = true;
    programs.adb.enable = true;

    environment.systemPackages = with pkgs; [
      # Compilers and build tools
      gcc13
      cmake
      meson
      ninja
      pkg-config

      # Language runtimes
      nodejs_20
      openjdk
      typescript
      node2nix

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
      nodePackages.aws-cdk

      # Kubernetes tools
      k3s
      (wrapHelm pkgs-unstable.kubernetes-helm {
        plugins = with pkgs-unstable.kubernetes-helmPlugins; [
          helm-secrets
          helm-diff
          helm-s3
          helm-git
        ];
      })
      pkgs-unstable.kubernetes-helm
      pkgs-unstable.helmfile
      pkgs-unstable.kustomize
      pkgs-unstable.kompose
      kubevirt
      pkgs-unstable.krew
    ];
  };
}
