final: prev: let
  pkgs = import <nixpkgs> {  }; 
in rec {
  python = prev.python311.override {
    packageOverrides = final: prev: {
      python-xlib = prev.buildPythonPackage rec {
        pname = "python-xlib";
        version = "0.31";
        format = "pyproject";
        doCheck = false;
        BuildInputs = [
          pkgs.python311Packages.setuptools
          pkgs.python311Packages.setuptools-scm
          pkgs.python311Packages.six
        ];
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = "sha256-dNg6CB9TK8B/bXr81kFuw4QD1o9oubncnh8o+/LXmek=";
        };
      };
    };
  };
  python-xlib = python.pkgs.buildPythonPackage rec {
    pname = "python-xlib";
    version = "0.31";
    format = "pyproject";
    doCheck = false;
    nativeBuildInputs = [
      python.pkgs.setuptools
      python.pkgs.setuptools-scm
      python.pkgs.six
    ];
    src = python.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-dNg6CB9TK8B/bXr81kFuw4QD1o9oubncnh8o+/LXmek=";
    };
  };
}
