final: prev:
rec {
  python-materialyoucolor-init = prev.python312.override {
    packageOverrides = final: prev: {
      python-xlib = prev.buildPythonPackage rec {
        pname = "materialyoucolor";
        version = "2.0.9";
        format = "pyproject";
        doCheck = false;
        BuildInputs = with prev.pkgs.python312Packages; [
          six
        ];
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = "sha256-J35//h3tWn20f5ej6OXaw4NKnxung9q7m0E4Zf9PUw4=";
        };
      };
    };
  };
  materialyoucolor = python-materialyoucolor-init.pkgs.buildPythonPackage rec {
    pname = "materialyoucolor";
    version = "2.0.9";
    format = "pyproject";
    doCheck = false;
    nativeBuildInputs = with python-materialyoucolor-init.pkgs; [
      setuptools
      setuptools-scm
      six
    ];
    src = python-materialyoucolor-init.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-J35//h3tWn20f5ej6OXaw4NKnxung9q7m0E4Zf9PUw4=";
    };
  };
}