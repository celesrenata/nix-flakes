final: prev:
{
  nmap = prev.nmap.overrideAttrs(old: rec {
    nativeBuildInputs = old.nativeBuildInputs ++ [
      prev.pkgs.gobject-introspection
      prev.pkgs.python312Packages.build
      prev.pkgs.python312Packages.setuptools
      (prev.python3.withPackages(pypkgs: [
        pypkgs.pygobject3
      ]))
      prev.pkgs.wrapGAppsHook
    ];

    buildInputs = old.buildInputs ++ [
      prev.pkgs.gtk3
    ];

    configureFlags = prev.lib.remove "--without-zenmap" (prev.lib.flatten old.configureFlags);

    installPhase = ''
      cd zenmap
      python setup.py install --prefix=$out
      sed -i "58a sys.path.append(\"$out/lib/python${prev.python3.sourceVersion.major}.${prev.python3.sourceVersion.minor}/site-packages/\")" $out/bin/zenmap
    '';
  });
}
