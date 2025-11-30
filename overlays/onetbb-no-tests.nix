self: super: {
  onetbb = super.onetbb.overrideAttrs (oldAttrs: {
    doCheck = false;
  });
}
