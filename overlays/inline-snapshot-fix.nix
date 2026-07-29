# Python package fixes for nixpkgs issues
# - inline-snapshot 0.32.5: 3 tests fail (transitive dep of mcp Python SDK)
# - gguf: nixpkgs uses llama.cpp rev (9967) as version but metadata says 0.19.0
# - pipx: test_inject parametrize mismatch (nixpkgs already sets doCheck=false)
# - ultralytics: setuptools<=82.0.1 constraint vs nixpkgs 83.0.0
# - mcp-nixos: flaky test_read_text_file assertion (finds "Error" in random nix store file)
final: prev: {
  # Top-level package fix (not in python3Packages)
  mcp-nixos = prev.mcp-nixos.overrideAttrs (old: {
    doInstallCheck = false;
    doCheck = false;
  });
  python3 = prev.python3.override {
    packageOverrides = pyfinal: pyprev: {
      inline-snapshot = pyprev.inline-snapshot.overridePythonAttrs (old: {
        doCheck = false;
      });
      gguf = pyprev.gguf.overridePythonAttrs (old: {
        dontCheckPythonMetadata = true;
      });
      pipx = pyprev.pipx.overridePythonAttrs (old: {
        doCheck = false;
      });
      ultralytics = pyprev.ultralytics.overridePythonAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          sed -i 's/setuptools>=70.0.0,<=82.0.1/setuptools>=70.0.0/' pyproject.toml
          sed -i 's/setuptools<=81.0.0/setuptools/' pyproject.toml
        '';
      });
    };
  };
  python3Packages = final.python3.pkgs;
}
