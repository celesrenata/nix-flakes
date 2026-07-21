# Fix for inline-snapshot 0.32.5 failing tests in nixpkgs
# This is a transitive dependency of the mcp Python SDK.
# 3 tests fail due to upstream issues unrelated to our code.
final: prev: {
  python312Packages = prev.python312Packages.override {
    overrides = self: super: {
      inline-snapshot = super.inline-snapshot.overridePythonAttrs (old: {
        doCheck = false;
      });
    };
  };
}
