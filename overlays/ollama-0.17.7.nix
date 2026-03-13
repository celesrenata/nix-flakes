final: prev:
let
  inherit (prev) lib buildGoModule fetchFromGitHub buildEnv makeBinaryWrapper stdenv 
                 addDriverRunpath cmake gitMinimal cudaPackages autoAddDriverRunpath
                 versionCheckHook writableTmpDirAsHomeHook;
  
  enableCuda = true;
  
  cudaLibs = [ cudaPackages.cuda_cudart cudaPackages.libcublas cudaPackages.cuda_cccl ];
  cudaMajorVersion = lib.versions.major cudaPackages.cuda_cudart.version;
  
  cudaToolkit = buildEnv {
    name = "cuda-merged-${cudaMajorVersion}";
    paths = map lib.getLib cudaLibs ++ [
      (lib.getOutput "static" cudaPackages.cuda_cudart)
      (lib.getBin (cudaPackages.cuda_nvcc.__spliced.buildHost or cudaPackages.cuda_nvcc))
    ];
  };
  
  cudaPath = lib.removeSuffix "-${cudaMajorVersion}" cudaToolkit;
  
  wrapperArgs = builtins.concatStringsSep " " [
    "--suffix LD_LIBRARY_PATH : '${addDriverRunpath.driverLink}/lib'"
    "--suffix LD_LIBRARY_PATH : '${lib.makeLibraryPath (map lib.getLib cudaLibs)}'"
  ];
  
  goBuild = buildGoModule.override { stdenv = cudaPackages.backendStdenv; };
in
{
  ollama = goBuild {
    pname = "ollama";
    version = "0.17.7";
    
    src = fetchFromGitHub {
      owner = "ollama";
      repo = "ollama";
      tag = "v0.17.7";
      hash = "sha256-cAqc38NHvUo5gphq1csTyosTcpUjFcs0dzB0wreEGjs=";
    };
    
    vendorHash = "sha256-Lc1Ktdqtv2VhJQssk8K1UOimeEjVNvDWePE9WkamCos=";
    proxyVendor = true;
    
    env.CUDA_PATH = cudaPath;
    
    nativeBuildInputs = [ cmake gitMinimal cudaPackages.cuda_nvcc makeBinaryWrapper autoAddDriverRunpath ];
    buildInputs = cudaLibs;
    
    postPatch = ''
      substituteInPlace version/version.go --replace-fail 0.0.0 '0.17.7'
      rm -r app
    '';
    
    overrideModAttrs = _: { preBuild = ""; };
    
    preBuild = let
      removeSMPrefix = str: let matched = builtins.match "sm_(.*)" str; in if matched == null then str else builtins.head matched;
      cudaArchitectures = builtins.concatStringsSep ";" (map removeSMPrefix cudaPackages.flags.realArches);
    in ''
      cmake -B build \
        -DCMAKE_SKIP_BUILD_RPATH=ON \
        -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
        -DCMAKE_CUDA_ARCHITECTURES='${cudaArchitectures}'
      cmake --build build -j $NIX_BUILD_CORES
    '';
    
    postInstall = ''
      mkdir -p $out/lib
      cp -r build/lib/ollama $out/lib/
    '';
    
    postFixup = ''
      wrapProgram "$out/bin/ollama" ${wrapperArgs}
    '';
    
    ldflags = [
      "-X=github.com/ollama/ollama/version.Version=0.17.7"
      "-X=github.com/ollama/ollama/server.mode=release"
    ];
    
    checkFlags = [ "-skip=^TestPushHandler/unauthorized_push$" ];
    doInstallCheck = true;
    nativeInstallCheckInputs = [ versionCheckHook writableTmpDirAsHomeHook ];
    versionCheckKeepEnvironment = "HOME";
  };
}
