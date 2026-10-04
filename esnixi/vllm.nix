{ config, lib, pkgs, pkgsAccel, ... }:

let
  cuda13Packages = pkgs.cudaPackages_13_3.overrideScope (_: previous: {
    cccl = previous.cccl.overrideAttrs (old: {
      # CUDA 13.3 already contains this nixpkgs fix; reapplying it fails.
      patches = lib.filter (patch: !(lib.hasInfix "fix-invalid-cpp-syntax" (toString patch))) (old.patches or [ ]);
    });
  });
  cuda13Toolkit = pkgs.symlinkJoin {
    name = "cuda13.3-toolkit-runtime";
    paths = [
      cuda13Packages.cuda_nvcc
      cuda13Packages.cuda_cudart
      cuda13Packages.libcublas.include
      cuda13Packages.libcublas.lib
      pkgs.cudaPackages.cudatoolkit
    ];
    postBuild = ''
      # Nix's CUDA nvcc package keeps crt headers under bin/crt, while
      # cuda_runtime.h includes them as include-relative crt/*. Expose the
      # expected toolkit layout for FlashInfer's runtime JIT builds.
      mkdir -p "$out/include"
      ln -s ${pkgs.cudaPackages.cudatoolkit}/include/crt "$out/include/crt"
      for header in ${pkgs.cudaPackages.cudatoolkit}/include/curand*; do
        ln -sfn "$header" "$out/include/$(basename "$header")"
      done
      ln -s "$out/lib" "$out/lib64"
      ln -sf ${pkgs.cudaPackages.cudatoolkit}/lib/stubs/libcuda.so "$out/lib/stubs/libcuda.so"
    '';
  };
  quackKernels = pkgs.python314Packages."quack-kernels";
  flashinferPython = lib.findFirst (p: lib.hasInfix "flashinfer-python" (p.name or "")) (throw "vLLM dependency set does not contain FlashInfer") pkgsAccel.vllm.requiredPythonModules;
  # FlashInfer 0.6.18 provides set_autotune_process_group in its current
  # flashinfer.autotuner package; the former compatibility copy is obsolete.
  vllmPythonPath = lib.concatStringsSep ":" ([ "${pynvmlShim}" "${pkgsAccel.vllm}/lib/python3.14/site-packages" "${pkgsAccel.python3Packages.torch}/lib/python3.14/site-packages" "${quackKernels}/lib/python3.14/site-packages" ] ++ (map (p: "${p}/lib/python3.14/site-packages") pkgsAccel.vllm.requiredPythonModules));
  # tvm-ffi C++ headers needed by flashinfer JIT compilation
  tvmFfiHeaders = pkgs.fetchFromGitHub {
    owner = "mlc-ai";
    repo = "tvm-ffi";
    rev = "583e4b73c11aa3257e7be862834b98f33c39a6dd";
    hash = "sha256-noVRm8ba5DEM1qAYP8FzHuGA+KFWlR9w2GBBRsj/zhA=";
    fetchSubmodules = true;
  };

  # Python shim for tvm_ffi module (flashinfer 0.6.4+ requires it)
  tvmFfiShim = pkgs.writeTextDir "tvm_ffi/__init__.py" ''
    """tvm_ffi shim for flashinfer JIT compatibility."""

    class _LibInfo:
        @staticmethod
        def find_include_path():
            return "${tvmFfiHeaders}/include"

        @staticmethod
        def find_dlpack_include_path():
            return "${tvmFfiHeaders}/3rdparty/dlpack/include"

    libinfo = _LibInfo()

    def register_func(name, func=None, override=False):
        if func: return func
        return lambda f: f

    def load_module(path):
        import ctypes
        return ctypes.CDLL(str(path))

    def get_global_func(name, allow_missing=False):
        return None
  '';

  pynvmlShim = pkgs.writeTextDir "pynvml/__init__.py" ''
    import ctypes

    _lib = ctypes.CDLL("libnvidia-ml.so.1")
    _lib.nvmlInit_v2.restype = ctypes.c_int
    _lib.nvmlShutdown.restype = ctypes.c_int
    _lib.nvmlDeviceGetCount_v2.argtypes = [ctypes.POINTER(ctypes.c_uint)]
    _lib.nvmlDeviceGetCount_v2.restype = ctypes.c_int

    def nvmlInit():
        return _lib.nvmlInit_v2()

    def nvmlShutdown():
        return _lib.nvmlShutdown()

    def nvmlDeviceGetCount():
        count = ctypes.c_uint()
        result = _lib.nvmlDeviceGetCount_v2(ctypes.byref(count))
        if result != 0:
            raise RuntimeError(f"NVML error {result}")
        return count.value
  '';

  vllmEnvironment = {
    VLLM_TARGET_DEVICE = "cuda";
    CUDA_VISIBLE_DEVICES = "0";
    HOME = "/var/lib/vllm";
    HF_TOKEN_PATH = "${config.sops.secrets.huggingface_token.path}";
    # We prefetch both snapshots; serving must not stall on Hub metadata checks.
    HF_HUB_OFFLINE = "1";
    TRANSFORMERS_OFFLINE = "1";
    PYTHONPATH = vllmPythonPath;
    CUDA_HOME = cuda13Toolkit;
    CUDA_TOOLKIT_PATH = cuda13Toolkit;
    CUDACXX = "${cuda13Toolkit}/bin/nvcc";
    CC = "${pkgs.gcc14}/bin/gcc";
    CXX = "${pkgs.gcc14}/bin/g++";
    LD_LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${config.hardware.nvidia.package}/lib";
    LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudatoolkit}/lib/stubs:${config.hardware.nvidia.package}/lib";
  };

  vllmPath = [
    pkgs.bash
    pkgs.gcc14
    pkgs.binutils
    pkgs.cudaPackages.cudatoolkit
    pkgs.ninja
  ];

  # sleepMode: vLLM sleep mode (level 1) driven by vllm_idle.IdleSleepMiddleware. The
  # unit stays running; asleep, its weights sit in pinned host RAM and it releases the
  # shared 5090 lease, so the other sleep-mode unit (or ComfyUI) can take the GPU and
  # waking costs seconds instead of a cold start. idleSeconds = "0" sleeps only when
  # the switcher asks (POST /arcane/sleep). Requires leaseWrap.
  # With a fixed kvCacheMemory, vLLM still refuses to start unless free VRAM >=
  # gpuMemoryUtilization x card (default 0.92). A sleeping unit keeps a residual
  # (measured 2026-10-03: coder 2.30 GiB, reader 1.56 GiB) plus ~0.93 GiB of desktop.
  # Sleep-mode units therefore pass gpuMemoryUtilization as that startup gate only;
  # set it just above the unit's real awake footprint.
  mkVllmService = { model, servedModel, extraArgs, gpuMemoryUtilization ? "0.79", maxModelLen ? "131072", maxNumSeqs ? "1", kvCacheMemory ? null, kvOffloadingSize ? null, wantedBy ? [ ], conflicts ? [ ], leaseWrap ? false, port ? "8010", sleepMode ? false, idleSeconds ? "0", restart ? "on-failure" }:
    assert sleepMode -> leaseWrap;
    {
      description = "vLLM OpenAI-compatible API server (${servedModel})";
      after = [ "network.target" ] ++ lib.optionals leaseWrap [ "arcane-gpu-lock.service" ];
      requires = lib.optionals leaseWrap [ "arcane-gpu-lock.service" ];
      inherit wantedBy conflicts;
      environment = vllmEnvironment // lib.optionalAttrs leaseWrap {
        ARCANE_GPU_LOCK = "/run/arcane-gpu/5090.lock";
      } // lib.optionalAttrs sleepMode {
        # vllm_idle.py + arcane_gpu.py for --middleware.
        PYTHONPATH = "${gpuRuntime}:${vllmPythonPath}";
        VLLM_IDLE_SECONDS = idleSeconds;
        VLLM_LEASE_WAIT_SECONDS = "60";
      };
      path = vllmPath;
      serviceConfig = {
        Type = "simple";
        User = "vllm";
        Group = "vllm";
        # When leaseWrap is set, acquire the shared RTX 5090 flock via gpu_launch.py
        # BEFORE vLLM loads any CUDA weights; gpu_launch.py execs into the command
        # below, and the kernel releases the advisory lock when the process exits.
        ExecStart = "${lib.optionalString leaseWrap "${pkgs.python3}/bin/python3 ${gpuLaunch} "}${pkgsAccel.vllm}/bin/vllm serve ${model} --served-model-name ${servedModel} --host 127.0.0.1 --port ${port} --max-model-len ${maxModelLen} --max-num-seqs ${maxNumSeqs} ${if kvCacheMemory != null then "--kv-cache-memory=${toString kvCacheMemory}${lib.optionalString sleepMode " --gpu-memory-utilization ${gpuMemoryUtilization}"}" else "--gpu-memory-utilization ${gpuMemoryUtilization}"} --kv-cache-dtype nvfp4 ${lib.optionalString (kvOffloadingSize != null) "--kv-offloading-size ${toString kvOffloadingSize} --kv-offloading-backend native"}${lib.optionalString sleepMode " --enable-sleep-mode --api-server-count 1 --middleware vllm_idle.IdleSleepMiddleware"} ${extraArgs}";
        Restart = restart;
        RestartSec = "10s";
        TimeoutStopSec = "120s";
      };
    };

  switcherScript = pkgs.writeText "vllm-switch.py" (builtins.readFile ./vllm-switch.py);
  # Shared GPU-lease wrapper (same script the vision container uses): takes an
  # exclusive flock on /run/arcane-gpu/5090.lock, marks the fd inheritable, then
  # execs into vLLM so the kernel releases the lease when the process dies.
  gpuLaunch = ./gpu_launch.py;
  gpuRuntime = import ./gpu-runtime.nix { inherit pkgs; };
in
{
  sops.secrets.huggingface_token = {
    sopsFile = ../secrets/secrets.yaml;
    owner = "vllm";
    group = "vllm";
  };

  systemd.services.vllm = mkVllmService {
    model = "nvidia/Qwen3.8-27B-NVFP4";
    servedModel = "qwen3.8-27b-nvfp4";
    leaseWrap = true;
    # Co-resident with the reader (sleep mode swaps them); only the fallback, which
    # binds the same port without sleep mode, is exclusive.
    conflicts = [ "vllm-5090-fallback.service" ];
    sleepMode = true;
    # Never auto-sleeps: sleeping discards the GPU prefix cache, so the coder sleeps
    # only when the switcher hands the GPU to the reader.
    idleSeconds = "0";
    # Startup gate only (KV is fixed): awake footprint ~29.5 GiB, and 0.92 x 31.45 GiB
    # usable = 28.93 GiB. A sleeping reader leaves only ~28.60 GiB free, so the coder
    # refuses to start instead of OOMing after loading.
    gpuMemoryUtilization = "0.92";
    # The built-in MTP head is substantially faster than DFlash2 on this
    # target while preserving the full production context.
    # 2 concurrent sequences. maxModelLen, maxNumSeqs and port are COUPLED to
    # vllm-switch.py MODELS["qwen3.8-27b-nvfp4"] and ["qwen3.8-27b-nvfp4-balanced"]
    # (context == maxModelLen, max_requests == maxNumSeqs, port == port);
    # test_vllm_switch.py parses this block and asserts them. Change them together.
    port = "8010";
    # 5.5 GiB nvfp4 KV = 105 hybrid blocks of 2848 tokens (104 usable). Each sequence
    # also holds 15 GDN state blocks (3 groups x (2 + 3 MTP spec)), so without a shared
    # prefix it fits 3 x 54K or 2 x 57K (4 x 57K with a ~40K shared Zoo prefix).
    # One max-length 163840 sequence = 58 blocks + 15 GDN state = 73 of 104 usable (maxNumSeqs now 2). Peak
    # free is ~1.0 GiB with the reader stopped (29708 + 512 MiB of 32202 MiB usable);
    # the switcher stops the reader (not sleeps it) whenever it selects the coder.
    # 32 GiB of host RAM is a pinned CPU tier (native OffloadingConnector) for
    # evicted prefix-cache blocks. Upstream #45268 reports sleep mode + native
    # offload crashing after a wake; if that hits, drop kvOffloadingSize.
    kvCacheMemory = 5905580032;
    kvOffloadingSize = 32;
    maxModelLen = "163840";
    maxNumSeqs = "2";
    # 5760 = 2 x 2848-token blocks (mamba align mode cuts prefill chunks to block multiples) + 64 slots for the other seqs MTP decode tokens.
    extraArgs = "--language-model-only --linear-backend cutlass --reasoning-parser qwen3 --tool-call-parser qwen3_xml --enable-auto-tool-choice --max-num-batched-tokens 5760 --speculative-config '{\"method\":\"mtp\",\"num_speculative_tokens\":3}'";
  };

  # NVFP4 9B reader (AxionML/Qwen3.5-9B-NVFP4, modelopt_fp4 W4A4; vLLM auto-promotes
  # weight-only NVFP4 to W4A16 from the checkpoint config) + NVFP4 KV on SM120.
  # Started ONLY by the switcher (wantedBy = [ ]). Never co-resident with an awake
  # coder: the switcher stops it (its 1.56 GiB sleep residual does not fit next to the
  # coder's KV) whenever it selects the coder, and sleeps the coder to run it. It
  # sleeps itself after 5 minutes idle only to free the lease for ComfyUI while the
  # coder is asleep.
  # --max-model-len 65536 and port 8012 are COUPLED to the switcher
  # MODELS["qwen3.5-9b-nvfp4-reader"] ["context"]/["port"] in vllm-switch.py — change
  # BOTH together or the readiness poll never matches and the reader tier goes dead.
  systemd.services.vllm-reader = mkVllmService {
    model = "AxionML/Qwen3.5-9B-NVFP4";
    servedModel = "qwen3.5-9b-nvfp4-reader";
    leaseWrap = true;
    conflicts = [ "vllm-5090-fallback.service" ];
    wantedBy = [ ];
    # The switcher owns the reader's lifecycle: a crash goes straight to `failed`
    # (fast detection, circuit breaker, coder rollback) instead of systemd
    # auto-restarting it and re-taking the GPU flock the coder needs to wake.
    restart = "no";
    sleepMode = true;
    idleSeconds = "300";
    port = "8012";
    # Fixed 4 GiB KV (~390K tokens, ~6 x 65536) instead of 0.85 utilization: the
    # reader must start in the space the sleeping coder leaves, and a fixed size
    # skips profiling against whatever is free at that moment.
    kvCacheMemory = 4294967296;
    # Startup gate only (KV is fixed): awake footprint ~15.5 GiB (8.4 weights + 4 KV
    # + ~2 activations + graphs/context); 0.50 = 15.7 GiB free.
    gpuMemoryUtilization = "0.50";
    maxModelLen = "65536";
    maxNumSeqs = "16";
    # Generous batching so the 9B "flies" on the 5090: real paged/continuous-batching
    # KV, CUDA graphs on (NO --enforce-eager).
    extraArgs = "--linear-backend cutlass --max-num-batched-tokens 8192 --reasoning-parser qwen3 --tool-call-parser qwen3_xml --enable-auto-tool-choice";
  };

  # Dormant native disaster-recovery fallback reusing the same patched pkgsAccel.vllm
  # as the coder (replaces the retired stock-image docker-vllm-5090 container).
  # wantedBy = [ ] (the autoStart=false analog); binds the same 127.0.0.1:8010 so it
  # conflicts with both the coder and the reader. Operator-started only.
  systemd.services.vllm-5090-fallback = mkVllmService {
    model = "nvidia/Qwen3.8-27B-NVFP4";
    servedModel = "qwen3.8-27b-nvfp4";
    leaseWrap = true;
    conflicts = [ "vllm.service" "vllm-reader.service" ];
    wantedBy = [ ];
    gpuMemoryUtilization = "0.75";
    maxModelLen = "24576";
    maxNumSeqs = "1";
    extraArgs = "--language-model-only --reasoning-parser qwen3 --tool-call-parser qwen3_xml --enable-auto-tool-choice";
  };

  sops.secrets.vllm_switcher_token = {
    sopsFile = ../secrets/secrets.yaml;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  users.users.vllm-switcher = {
    isSystemUser = true;
    group = "vllm-switcher";
  };
  users.groups.vllm-switcher = { };

  security.sudo.extraRules = [
    {
      users = [ "vllm-switcher" ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl start vllm.service"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl stop vllm.service"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl reset-failed vllm.service"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl start vllm-reader.service"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl stop vllm-reader.service"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl reset-failed vllm-reader.service"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  systemd.services.vllm-switcher = {
    description = "Authenticated automatic vLLM model switcher for the RTX 5090";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      SYSTEMCTL = "${pkgs.systemd}/bin/systemctl";
      SUDO = "/run/wrappers/bin/sudo";
      # Residency of the idle READER against a coder request (409 to the next
      # OmniRoute target inside the window). 0: the coder reclaims the GPU at once.
      VLLM_SWITCH_RESIDENCY_SECONDS = "0";
      # The coder is the protected default: a reader request never evicts it while
      # it has requests in flight or within this many seconds of its last use.
      VLLM_SWITCH_CODER_RESIDENCY_SECONDS = "90";
      # Circuit breaker after a failed switch: first backoff, doubling up to the max.
      # Requests for a target in backoff get an immediate 409; the active model is
      # left untouched.
      VLLM_SWITCH_BACKOFF_SECONDS = "300";
      VLLM_SWITCH_BACKOFF_MAX_SECONDS = "1800";
      # Watchdog: with no ready model for this long, ready (wake/start) the coder.
      VLLM_SWITCH_WATCHDOG_SECONDS = "60";
      # Deadlines: sleep budget before falling back to stop, stop+drain (above
      # TimeoutStopSec), and readiness for one switch.
      VLLM_SWITCH_SLEEP_SECONDS = "90";
      VLLM_SWITCH_STOP_SECONDS = "150";
      VLLM_SWITCH_START_SECONDS = "300";
    };
    serviceConfig = {
      Type = "simple";
      User = "vllm-switcher";
      Group = "vllm-switcher";
      ExecStart = "${pkgs.python3}/bin/python3 ${switcherScript}";
      LoadCredential = [ "bearer-token:${config.sops.secrets.vllm_switcher_token.path}" ];
      Restart = "always";
      RestartSec = "2s";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
    };
  };

  # The former vllm-reader-idle stop timer is gone: an idle reader puts itself to
  # sleep (vllm_idle.py, idleSeconds); the switcher stops it when the coder is selected.

  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    home = "/var/lib/vllm";
    createHome = true;
  };

  users.groups.vllm = {};
}
