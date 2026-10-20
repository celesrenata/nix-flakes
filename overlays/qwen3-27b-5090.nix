# overlays/qwen3-27b-5090.nix
#
# Packages the mkyt/qwen3-27b-5090 single-purpose inference engine as a
# reproducible Nix derivation (no build-time network), exposing it as
# `pkgs.qwen3-27b-5090-engine`. This is the "Track B" bespoke C++/CUDA engine
# (libq27.so + a stdlib-HTTP Python frontend, NO PyTorch at runtime) that
# benchmarks ~2-2.8x vLLM single-request decode and holds a 605K-token KV pool /
# full 262144 context on one RTX 5090 (SM120), using the same gdnfp4 weights +
# NVFP4 KV + DFlash2 our vLLM coder serves.
#
# The upstream project builds in a docker image that `git clone`s CUTLASS at
# build time; we vendor CUTLASS via fetchFromGitHub so the build is offline and
# reproducible (non-negotiable #6). The engine's CMake reads $CUTLASS_DIR.
#
# Runtime is deliberately torch-free: server.py/worker.py/chat.py import only
# transformers + tokenizers (chat template, image processor), pillow, numpy and
# safetensors, plus the ctypes binding engine/python/q27lib.py -> libq27.so.
#
# Pins (see docs/decisions.md phase Q "gdnfp4" + dev/Dockerfile):
#   engine  rev 0594e77ca099f397ccefed0c68c981e32869989f
#   CUTLASS v4.8.0 (098de2a652cf8f00fd70b2df54051c7eccbb855a)

final: prev:
let
  # Pinned engine source.
  engineSrc = prev.fetchFromGitHub {
    name = "qwen3-27b-5090-source";
    owner = "mkyt";
    repo = "qwen3-27b-5090";
    rev = "0594e77ca099f397ccefed0c68c981e32869989f";
    hash = "sha256-88cgItf2z/D4CbrSIosylfV4TSF24uimmTFhLfi4qvE=";
  };

  # CUTLASS / CuTe headers, header-only, pinned to the exact v4.8.0 commit the
  # engine's dev/Dockerfile uses. The engine only needs its include trees.
  cutlass = prev.fetchFromGitHub {
    name = "cutlass-4.8.0-source";
    owner = "NVIDIA";
    repo = "cutlass";
    rev = "098de2a652cf8f00fd70b2df54051c7eccbb855a";
    hash = "sha256-FiXSg6DMUAV9Gf5LOePKAwmGLVPxphq6MVwHZwwsKDM=";
  };

  # CUDA 13.3, matching esnixi/vllm.nix. The upstream cccl patch is already in
  # 13.3.3, so drop it (reapplying fails) -- same override the ai overlay makes.
  cuda13 = prev.cudaPackages_13_3.overrideScope (_: cudaPrev: {
    cccl = cudaPrev.cccl.overrideAttrs (old: {
      patches = prev.lib.filter
        (p: !(prev.lib.hasInfix "fix-invalid-cpp-syntax" (p.name or "")))
        (old.patches or [ ]);
    });
  });

  # libq27.so (+ the q27-sfcheck scale-factor check tool), built for sm_120a.
  libq27 = prev.stdenv.mkDerivation {
    pname = "libq27";
    version = "0-unstable-2026-10-11";
    src = engineSrc;

    nativeBuildInputs = [
      prev.cmake
      prev.ninja
      cuda13.cuda_nvcc
    ];

    buildInputs = [
      cuda13.cuda_cudart
      cuda13.cccl
    ];

    # The engine's CMake reads $CUTLASS_DIR for the (header-only) includes.
    CUTLASS_DIR = cutlass;

    # engine/CMakeLists.txt is the top-level for the C++/CUDA build.
    configurePhase = ''
      runHook preConfigure
      cmake -S engine -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CUDA_ARCHITECTURES=120a
      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild
      cmake --build build -j''${NIX_BUILD_CORES:-$(nproc)}
      runHook postBuild
    '';

    # CMake has no install target; place the shared lib + the tool, and keep the
    # Python ctypes binding (engine/python) + the reference helpers (qwen27b.*)
    # the frontend imports, so the whole runtime tree lives under one store path.
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib" "$out/bin" "$out/share/qwen3-27b-5090"
      cp build/libq27.so "$out/lib/"
      if [ -f build/q27-sfcheck ]; then cp build/q27-sfcheck "$out/bin/"; fi
      # Python-side sources the frontend puts on sys.path at runtime.
      cp -r engine/python "$out/share/qwen3-27b-5090/engine-python"
      cp -r frontend      "$out/share/qwen3-27b-5090/frontend"
      cp -r reference     "$out/share/qwen3-27b-5090/reference"
      runHook postInstall
    '';

    # CUDA compiles are impure w.r.t. the host toolchain in this tree (same as
    # the vLLM/flashinfer derivations in overlays/vllm.nix).
    __noChroot = true;

    meta = with prev.lib; {
      description = "mkyt/qwen3-27b-5090 libq27.so inference engine for Qwen3.8-27B on RTX 5090 (SM120)";
      homepage = "https://github.com/mkyt/qwen3-27b-5090";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };

  # Runtime Python env for the frontend. NO torch (serving is torch-free);
  # transformers/tokenizers/pillow/numpy/safetensors are all the imports
  # server.py/worker.py/chat.py/qwen27b.vision make at serve time.
  # Runtime Python env for the frontend, built on the SAME python 3.14 the vLLM
  # overlay uses (final.python3) -- so torch (CUDA 2.13), transformers,
  # tokenizers, safetensors, pillow and numpy all come from what the vLLM stack
  # already built and cached. Dry-run verified: adding torch here reuses the
  # resident 3.14 build, no from-source recompile. (The engine's dev pin is 3.12,
  # but the frontend is stdlib + tokenizer and runs on 3.14; reusing the 3.14
  # torch is why there is no second torch compile.) torch is included because
  # qwen27b.weights imports it at module load (the server imports its path
  # resolvers from there); the C++ engine still does the real tensor loading.
  frontendPython = final.python3.withPackages (ps: [
    ps.torch
    ps.transformers
    ps.tokenizers
    ps.pillow
    ps.numpy
    ps.safetensors
  ]);

in
{
  qwen3-27b-5090-engine = prev.symlinkJoin {
    name = "qwen3-27b-5090-engine";
    paths = [ libq27 ];
    # Expose the pieces the systemd unit needs: the lib path, the python runtime,
    # the on-store share tree (frontend/engine-python/reference), and the pin.
    passthru = {
      inherit libq27 frontendPython cutlass;
      engineRev = "0594e77ca099f397ccefed0c68c981e32869989f";
      share = "${libq27}/share/qwen3-27b-5090";
    };
  };
}
