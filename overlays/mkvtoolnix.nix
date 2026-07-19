final: prev: {

  mkvtoolnix-cli = prev.mkvtoolnix-cli.overrideAttrs (oldAttrs: {
    # mkvtoolnix 100.0: the default rake target includes tests:unit when gtest
    # is available. tests:unit unconditionally depends on tests/unit/gui/gui,
    # but that target is skipped when withGUI=false, causing a build failure.
    # Remove gtest so $have_gtest=false and tests:unit isn't added to defaults.
    nativeBuildInputs = builtins.filter
      (drv: (drv.pname or drv.name or "") != "gtest")
      oldAttrs.nativeBuildInputs;
    doCheck = false;
  });
}
