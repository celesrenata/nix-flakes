final: prev:
rec {
  python-pydiffx-init = prev.python311.override {
    packageOverrides = final: prev: {
      python-pydiffx = prev.buildPythonPackage rec {
        pname = "pydiffx";
        version = "1.1";
        format = "pyproject";
        BuildInputs = with prev.pkgs.python311Packages; [
          setuptools
          six
        ];
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = "sha256-CYbbsKh8v3niROLxwOK2ltjoazhh6ilVdXph044Tkig=";
        };
      };
    };
  };
  python-pydiffx = python-pydiffx-init.pkgs.buildPythonPackage rec {
    pname = "pydiffx";
    version = "1.1";
    format = "pyproject";
    nativeBuildInputs = with python-pydiffx-init.pkgs; [
      setuptools
      six
    ];
    src = python-pydiffx-init.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-CYbbsKh8v3niROLxwOK2ltjoazhh6ilVdXph044Tkig=";
    };
  };
  python-housekeeping-init = prev.python311.override {
    packageOverrides = final: prev: {
      python-housekeeping = prev.buildPythonPackage rec {
        pname = "housekeeping";
        version = "1.1";
        format = "pyproject";
        BuildInputs = with prev.pkgs.python311Packages; [
          setuptools
        ];
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = "sha256-decfHMUBiFQG9r6BQQybBTYYcaPszN44kTNtoekkJrU=";
        };
      };
    };
  };
  python-housekeeping = python-housekeeping-init.pkgs.buildPythonPackage rec {
    pname = "housekeeping";
    version = "1.1";
    format = "pyproject";
    nativeBuildInputs = with python-housekeeping-init.pkgs; [
      setuptools
      typing-extensions
    ];
    src = python-housekeeping-init.pkgs.fetchPypi {
      inherit pname version;
      sha256 = "sha256-decfHMUBiFQG9r6BQQybBTYYcaPszN44kTNtoekkJrU=";
    };    
  };   
  rbtools-init = prev.python311.override {
    packageOverrides = final: prev: {
      rbtools = prev.buildPythonPackages rec {
        pname = "RBTools";
        version = "5.0";
        format = "pyproject";
        doCheck = false;
        BuildInputs = with prev.pkgs.python311Packages; [
          setuptools
        ];
        nativeBuildInputs = with prev.pkgs.python311Packages; [
          certifi
          colorama
          final.python-pydiffx
          final.python-housekeeping
          texttable
          typing-extensions
          tqdm
          importlib-metadata
          importlib-resources
        ];
        dependencies = with prev.pkgs.python311Packages; [
          certifi
          colorama
          final.python-pydiffx
          final.python-housekeeping
          texttable
          typing-extensions
          tqdm
          importlib-metadata
          importlib-resources
        ];
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = "sha256-vrNzEA0PLXBzcKbORJtvmBEN0AgazP/XZtlVzqFvCLw=";
        };
      };
    };
  };
  rbtoolsOverride = rbtools-init.pkgs.buildPythonPackage rec {
    pname = "RBTools";
    version = "5.0";
    format = "pyproject";
    doCheck = false;
    nativeBuildInputs = with prev.python311Packages; [
      setuptools
      certifi
      colorama
      final.python-pydiffx
      final.python-housekeeping
      texttable
      typing-extensions
      tqdm
      importlib-metadata
      importlib-resources
    ];
    src = prev.fetchPypi {
      inherit pname version;
      sha256 = "sha256-vrNzEA0PLXBzcKbORJtvmBEN0AgazP/XZtlVzqFvCLw=";
    };
  };
}
