final: prev:
rec {
  obs-backgroundremovalOverride = prev.stdenv.mkDerivation rec {
    pname = "obs-backgroundremoval";
    version = "1.1.13";

    src = prev.fetchFromGitHub {
      owner = "occ-ai";
      repo = "obs-backgroundremoval";
      rev = version;
      hash = "sha256-QoC9/HkwOXMoFNvcOxQkGCLLAJmsja801LKCNT9O9T0=";
    };

    nativeBuildInputs = with prev.pkgs; [ cmake ninja ];
    buildInputs = with prev.pkgs; [ obs-studio onnxruntime opencv qt6.qtbase curl cudaPackages.tensorrt cudaPackages.cudatoolkit cudaPackages.nccl];

    dontWrapQtApps = true;

    cmakeFlags = [
      "--preset linux-x86_64"
      "-DCMAKE_MODULE_PATH:PATH=${src}/cmake"
      "-DUSE_SYSTEM_ONNXRUNTIME=ON"
      "-DUSE_SYSTEM_OPENCV=ON"
      "-DDISABLE_ONNXRUNTIME_GPU=ON"
    ];

#    buildPhase = ''
#      cd ..
#      cmake --build build_x86_64 --parallel
#    '';

    buildPhase = ''
      cd ..
      cmake --build build_x86_64
    '';
    
    installPhase = ''
      cmake --install build_x86_64 --prefix "$out"
    '';

    meta = with prev.lib; {
      description = "OBS plugin to replace the background in portrait images and video";
      homepage = "https://github.com/royshil/obs-backgroundremoval";
      maintainers = with maintainers; [ zahrun ];
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };
}
