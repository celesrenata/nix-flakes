final: prev:

let
  kernel = prev.linuxPackages_6_15.kernel;
in
{
  v4l2loopback-0150 = prev.stdenv.mkDerivation rec {
    pname = "v4l2loopback";
    version = "0.15.0";
    src = prev.fetchFromGitHub {
      owner = "umlaeute";
      repo = "v4l2loopback";
      rev = "v0.15.0";
      sha256 = "sha256-fa3f8GDoQTkPppAysrkA7kHuU5z2P2pqI8dKhuKYh04=";
    };
    nativeBuildInputs = [ prev.kmod prev.autoconf kernel.dev ];
    buildPhase = ''
      echo "Building against kernel: ${kernel.modDirVersion} in ${kernel.dev}"
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build M=$PWD modules
    '';
    installPhase = ''
      mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
      cp v4l2loopback.ko $out/lib/modules/${kernel.modDirVersion}/extra/
    '';
    meta = with prev.lib; {
      description = "v4l2loopback kernel module version 0.14.0 (standalone, kernel 6.15)";
      homepage = "https://github.com/umlaeute/v4l2loopback";
      license = licenses.gpl2Plus;
      platforms = platforms.linux;
    };
  };
}

