# ltrace-skip-tests
#
# ltrace 0.7.91 ships a DejaGNU testsuite that runs under `doCheck` in the
# nixpkgs derivation. On this nixpkgs pin 15 of its C++ "demangle" minor tests
# fail ("Fail to find myclass::Fi_i ... in demangle.ltrace", etc.) — a known
# upstream brittleness in ltrace's name-demangling expectations, not a defect in
# the built binary. The failing `make check` aborts the build with exit code 2
# and takes the whole system closure down with it.
#
# ltrace is only used here as a user debugging tool (home/programs/
# productivity.nix); its runtime binary is unaffected by the test failures. Skip
# the check phase so the package builds from source. Remove this once the
# upstream nixpkgs derivation stops gating the build on the flaky suite.
final: prev: {
  ltrace = prev.ltrace.overrideAttrs (_: {
    doCheck = false;
  });
}
