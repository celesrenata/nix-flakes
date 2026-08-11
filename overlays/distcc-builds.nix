# Distribute compilation of heavy packages across gremlins via distcc + ccache
final: prev:
let
  distccEnv = ''
    export DISTCC_DIR="$TMPDIR/distcc"
    mkdir -p "$DISTCC_DIR"
    export DISTCC_HOSTS="localhost/16 10.1.1.12/16,lzo 10.1.1.13/16,lzo 10.1.1.14/16,lzo 10.1.1.15/16,lzo"
    export CMAKE_C_COMPILER_LAUNCHER="distcc;ccache"
    export CMAKE_CXX_COMPILER_LAUNCHER="distcc;ccache"
    export CMAKE_CUDA_COMPILER_LAUNCHER=ccache
    export CCACHE_DIR=/var/cache/ccache
    export CCACHE_MAXSIZE=50G
    mkdir -p /var/cache/ccache
  '';
  addDistcc = pkg: pkg.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.distcc prev.ccache ];
    preConfigure = (old.preConfigure or "") + distccEnv;
    __noChroot = true;
  });
in {
  # OpenCV
  opencv = addDistcc prev.opencv;

  # Linux kernel
  linuxPackages_latest = prev.linuxPackages_latest.extend (lpFinal: lpPrev: {
    kernel = lpPrev.kernel.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ prev.distcc prev.ccache ];
      preBuild = (old.preBuild or "") + distccEnv;
      __noChroot = true;
    });
  });
}
