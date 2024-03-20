let python-xlib = import ../pythonx-xlib/python-xlib.nix {  };
in final: prev: let
  pkgs = import <nixpkgs> {  };
in rec {
  python = prev.python311.override {
    packageOverrides = final: prev: {
      python-keyszer = prev.buildPythonPackage rec {
        pname = "keyszer";
        version = "0.6.0";
        format = "pyproject";
        buildInputs = with pkgs; [
          pkgs.python311Packages.hatchling
          pkgs.python311Packages.appdirs
          pkgs.python311Packages.evdev
          pkgs.python311Packages.inotify-simple
          pkgs.python311Packages.ordered-set
          pkgs.python311Packages.python-xlib
        ];
        src = pkgs.fetchPypi {
          inherit pname version;
          sha256 = "sha256-xaR63lEJFZdS9FQSZ8Q4uIpXxXU4F/sRRfzwCcmac/M=";
        };
      };
    };
  };

  python-keyszer = python.pkgs.buildPythonPackage rec {
    pname = "keyszer";
    version = "0.6.0";
    format = "pyproject";
    doCheck = false;
    nativeBuildInputs = [
      python.pkgs.hatchling
      python.pkgs.appdirs
      python.pkgs.evdev
      python.pkgs.inotify-simple
      python.pkgs.ordered-set
      final.python-xlib
    ];
    src = python.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-xaR63lEJFZdS9FQSZ8Q4uIpXxXU4F/sRRfzwCcmac/M=";
    };
  };
}
