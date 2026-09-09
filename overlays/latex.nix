final: prev:
rec {
  latexRes-package = prev.stdenv.mkDerivation rec {
    name = "latexRes";
    src = prev.fetchFromGitHub {
      owner = "ChrisDienes";
      repo = "latex_resume";
      rev = "bd4a777613e0d04463990a5b207917feb866d4dd";
      sha256 = "sha256-K6HTXs+rkB1FayxfzLjZytOZT40a9Jipz8B3AC9LPxI=";
    };
    installPhase = ''
      mkdir -p $out/tex/latex
      cp res.cls $out/tex/latex/res.cls
    '';
    pname = name;
    tlType = "run";
  };
  # asymptote (pulled in by texliveFull) builds its interactive "xasy" GUI
  # against PyQt5. On this nixpkgs pin, python3.14-pyqt5-5.15.10 fails to build:
  #
  #   Generating the QtCore bindings...
  #   _in_process.py: ABI v12 is being targeted but the PyQt5.QtCore module
  #                   doesn't support it
  #   ERROR Backend subprocess exited when trying to invoke build_wheel
  #
  # Root cause (verified): PyQt5 5.15.10 pins SIP ABI 12.13 (project.py:
  # ABI_VERSION = '12.13'), but the sip 6.15.1 / pyqt5-sip 12.17.0 toolchain in
  # this pin generates/targets a v12 ABI that PyQt5 5.15.10's QtCore bindings
  # reject. This is version skew between the SIP toolchain and PyQt5, and it
  # fails IDENTICALLY under Python 3.13 and 3.14 (confirmed by building both) —
  # so it is not an interpreter problem, and there is no Qt6 asymptote in
  # nixpkgs (even asymptote 3.12 still uses libsForQt5 + pyqt5).
  #
  # Fix: build asymptote WITHOUT a working PyQt5 xasy GUI. TeX Live's LaTeX
  # integration only invokes the `asy` CLI to render .asy figures; xasy is a
  # standalone interactive editor that a LaTeX build never calls. We swap in a
  # Python whose package set replaces pyqt5 with a trivial buildable stub, so
  # `python3.withPackages [ ... pyqt5 ]` no longer drags in the broken PyQt5
  # build. asymptote's own postInstall still installs/wraps xasy.py, but it
  # simply won't launch (no real PyQt5) — harmless, since nothing invokes it.
  # The `asy` binary does not link PyQt5, so this keeps full LaTeX .asy
  # rendering while eliminating the broken derivation from the closure.
  pythonNoPyQt5 = prev.python3.override {
    self = pythonNoPyQt5;
    packageOverrides = pySelf: pySuper: {
      # Minimal buildable placeholder that satisfies withPackages' dependency
      # on `pyqt5` without building the broken PyQt5 5.15.10 wheel.
      pyqt5 = pySuper.buildPythonPackage {
        pname = "pyqt5-stub";
        version = "0";
        format = "other";
        dontUnpack = true;
        installPhase = ''
          mkdir -p "$out/${pySuper.python.sitePackages}"
        '';
      };
    };
  };

  asymptote = prev.asymptote.override { python3 = pythonNoPyQt5; };

  tex = final.texliveFull.withPackages (_: [ latexRes-package ]);
}
