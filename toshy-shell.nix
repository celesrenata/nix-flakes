{ pkgs ? import <nixpkgs> {
  overlays = let
  
      in [
        (import ./overlays/toshy.nix)
      ];
    }
  }: 
(pkgs.buildFHSUserEnv {
  name = "pipzone";
  targetPkgs = pkgs: (with pkgs; [
    pkg-config
    cairo.dev
    xorg.libxcb.dev
    xorg.libX11.dev
    xorg.xorgproto
    dbus.dev
    glib.dev
    systemd.dev
    linuxHeaders
    gobject-introspection
    gobject-introspection.dev
    libffi.dev
    python311
    python311Packages.pip
    python311Packages.virtualenv
    python311Packages.pycairo
    python311Packages.wheel
    python311Packages.setuptools
    python311Packages.pillow
    python311Packages.pygobject3
    python311Packages.lockfile
    python311Packages.dbus-python
    python311Packages.systemd
    python311Packages.tkinter
    python311Packages.sv-ttk
    python311Packages.watchdog
    python311Packages.psutil
    python311Packages.i3ipc
    python311Packages.pywayland
    python311Packages.pywlroots
    python-xlib
    python-xwaykeyz
    python-hyprpy
    gtk3
    wrapGAppsHook
    ]);
  profile = ''
    set -e
    # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
    # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
    export PIP_PREFIX=$(pwd)/_build/pip_packages
    export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
    export GI_TYPELIB_PATH="/nix/store/*-gtk+3-*/lib/girepository-1.0:$GI_TYPELIB_PATH"
    export PATH="$PIP_PREFIX/bin:$PATH"
    unset SOURCE_DATE_EPOCH
    set +e
   '';
  runScript = "bash";
}).env
