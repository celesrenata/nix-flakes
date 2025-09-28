final: prev: {
  python3Packages = prev.python3Packages // {
    # Temporarily disable xformers to avoid memory issues
    xformers = prev.python3Packages.buildPythonPackage {
      pname = "xformers-stub";
      version = "0.0.28.post3";
      src = prev.writeText "setup.py" "from setuptools import setup; setup(name='xformers', version='0.0.28.post3')";
      doCheck = false;
    };
  };
}
