{ pkgs ? import <nixpkgs> {
  overlays = let

      in [
        (import ./overlays/toshy.nix)
      ];
    }
  }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    libayatana-appindicator
    gobject-introspection
    wrapGAppsHook3
  ];
  buildInputs = with pkgs; [
    gtk3
    (python3.withPackages (p: with p; [
      dbus-python
      i3ipc
      lockfile
      pillow
      pygobject3
      psutil
      sv-ttk
      systemd-python
      watchdog
      python-xwaykeyz
      pywayland
      pywlroots
      python-hyprpy
    ]))
  ];
}
