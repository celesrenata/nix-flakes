# overlays/xformers-0_0_28_post3.nix
final: prev:
let
  inherit (prev.lib) fakeHash;
in {
  python312Packages = prev.python312Packages // {
    xformers_0_0_28_post3 =
      prev.python312Packages.buildPythonPackage rec {
        pname = "xformers";
        version = "0.0.28.post3";

        # Pull from PyPI; insert the correct sha256 after first build
        src = prev.fetchPypi {
          inherit pname version;
          sha256 = fakeHash; # replace with the real hash after first build
        };

        pyproject = true;

        # Build backends: xFormers builds C++/CUDA extensions via ninja/cmake
        nativeBuildInputs = [
          prev.cmake
          prev.ninja
          prev.pkg-config
          prev.python312Packages.setuptools
          prev.python312Packages.wheel
        ];

        propagatedBuildInputs = [
          prev.python312Packages.numpy
          prev.python312Packages.typing-extensions
          # Match whatever torch you use; keep ABI compatible with your environment
          prev.python312Packages.torch
        ];

        # Keep parallelism limited to 8 — works with cmake/ninja/torch’s extension builder
        NIX_BUILD_CORES = "8";
        MAX_JOBS = "8";                  # honored by PyTorch’s C++ extension build
        CMAKE_BUILD_PARALLEL_LEVEL = "8";
        NINJAFLAGS = "-j8";

        # Some projects honor this as well:
        # PARALLEL_BUILD = "8";

        # In case upstream uses make anywhere:
        makeFlags = (prev.lib.optional (prev.stdenv.isLinux) "-j8");

        # Optional; doesn’t hurt with Python pkgs and enables parallel compile step
        enableParallelBuilding = true;

        # Quick import check
        pythonImportsCheck = [ "xformers" ];

        # If you need CUDA/ROCm toolkits, add to buildInputs and set appropriate env:
        # buildInputs = [ prev.cudaPackages.cuda_nvcc ];
        # CUDAFLAGS / TORCH_CUDA_ARCH_LIST can go here if you build CUDA wheels.
      };
  };
}

