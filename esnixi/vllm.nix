{ config, lib, pkgs, pkgsAccel, ... }:

let
  # ── Coder checkpoint knob ───────────────────────────────────────────────
  # The HF weights the primary (and DR fallback) coder serves. Both options are
  # NVFP4, compressed-tensors (no --load-format change), and vision/MTP-capable,
  # and both are served under the SAME name "qwen3.8-27b-nvfp4" on port 8010 at
  # 163840 context / 2 seqs -- so vllm-switch.py and test_vllm_switch.py are
  # unaffected by the choice. If you switch to Minima, also update the two
  # hf_id/ALIASES lines in vllm-switch.py (metadata only; the served name and
  # all switch.py-coupled fields stay the same).
  #
  #   gdnfp4  = "juzbox/Qwen3.8-27B-NVFP4-GDN"  (DEFAULT)
  #     The nvidia checkpoint with the 48 GDN linear-attention projections
  #     (in_proj_qkv / in_proj_z / out_proj) ALSO quantized to NVFP4 (GPTQ from
  #     the BF16 original); MLP, lm_head, the 16 attention layers (FP8),
  #     embeddings, the MTP head and vision tower are NVIDIA's tensors unchanged.
  #     Format is ModelOpt MIXED_PRECISION (quant_method modelopt, group 16), so
  #     it loads on our patched vLLM with no --load-format change. Decode reads
  #     14.14 GiB of weights/token vs the nvidia checkpoint's 16.40 (~2.26 GiB
  #     less = the decode-bandwidth win), 19.50 GB on disk vs 21.92. Measured
  #     7-15% faster vLLM decode than nvidia with EQUAL GSM8K (95.7 vs 94.7) and
  #     BFCL v3 (89.8 vs 89.1) -- tool calling is preserved precisely because the
  #     ATTENTION projections stay FP8 (quantizing attention, not GDN, is what
  #     costs parallel tool calls; see the juzbox card + mkyt/qwen3-27b-5090
  #     decisions.md). Fused in_proj_qkv/in_proj_z share one weight global scale,
  #     which vLLM already handles (keeps the largest of a fused layer). This is
  #     the fastest checkpoint that keeps nvidia-level quality + full tool calls.
  #   nvidia  = "nvidia/Qwen3.8-27B-NVFP4"  (fallback)
  #     NVIDIA ModelOpt mixed-precision: NVFP4 on MLP + lm_head, FP8 on the
  #     self-attention AND the 48 GDN linear-attention layers; ships NO
  #     calibrated KV scales (its card serves fp8 KV). With our nvfp4 KV this
  #     runs at scale 1.0, which the Minima paper measures as a ~3x-larger
  #     long-context KV penalty on a quantized model vs calibrated scales.
  #   minima  = "minima-ai/mnma_qwen3.8_27b_nvfp4"
  #     All 496 linear layers NVFP4 W4A4 INCLUDING the GDN block, PLUS calibrated
  #     static per-tensor FP8 KV scales (arXiv 2609.04098). Smallest weights in
  #     its cohort (17.5 GiB -> frees VRAM for a larger nvfp4 KV pool), fastest
  #     prefill (+14-19% at 8K: GDN GEMMs run on 4-bit tensor cores, not FP8),
  #     and matches BF16 within seed noise on 6 suites. The calibrated scales
  #     make --kv-cache-dtype nvfp4 honest rather than scale-1.0, and are
  #     per-tensor TENSOR-strategy, which our vllm-sm120-nvfp4-kv.patch requires
  #     for num_bits=4 (it rejects per-head). All-NVFP4 (attention included) is
  #     measured to cost parallel tool calls, so gdnfp4 is preferred for the
  #     coding agent; minima is the pick if KV-scale-correctness matters more.
  coderCheckpoints = {
    gdnfp4 = "juzbox/Qwen3.8-27B-NVFP4-GDN";
    nvidia = "nvidia/Qwen3.8-27B-NVFP4";
    minima = "minima-ai/mnma_qwen3.8_27b_nvfp4";
  };
  # Default is the GDN-NVFP4 checkpoint: fastest vLLM decode at nvidia-level
  # quality + full tool calling, and 2.26 GiB/token less weight bandwidth. Flip
  # to coderCheckpoints.nvidia to roll back to the stock NVIDIA weights.
  coderCheckpoint = coderCheckpoints.gdnfp4;

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
  # FlashInfer 0.7.2 provides set_autotune_process_group in its current
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
    model = coderCheckpoint;
    servedModel = "qwen3.8-27b-nvfp4";
    leaseWrap = true;
    # The sole 5090 sleep-mode tenant; only the fallback, which binds the same port
    # without sleep mode, is exclusive.
    conflicts = [ "vllm-5090-fallback.service" ];
    sleepMode = true;
    # Never auto-sleeps: sleeping discards the GPU prefix cache, so the coder sleeps
    # only when the switcher hands the GPU to another lease holder (e.g. ComfyUI).
    idleSeconds = "0";
    # Startup gate only (KV is fixed): awake footprint ~29.5 GiB, and 0.92 x 31.45 GiB
    # usable = 28.93 GiB, so the coder refuses to start instead of OOMing after loading.
    gpuMemoryUtilization = "0.92";
    # The built-in MTP head is substantially faster than DFlash2 on this
    # target while preserving the full production context.
    # 1 concurrent sequence. maxModelLen, maxNumSeqs and port are COUPLED to
    # vllm-switch.py MODELS["qwen3.8-27b-nvfp4"] and ["qwen3.8-27b-nvfp4-balanced"]
    # (context == maxModelLen, max_requests == maxNumSeqs, port == port);
    # test_vllm_switch.py parses this block and asserts them. Change them together.
    port = "8010";
    # 6.0 GiB nvfp4 KV, pinned. Reclaims the VRAM that dropping maxNumSeqs 2 -> 1
    # frees (halved GDN spec-state buffer, the batch-size-2 CUDA-graph decode
    # capture, and the second prefill block's activation scratch after
    # --max-num-batched-tokens 5760 -> 2912) back INTO the KV pool instead of
    # leaving it idle -- the box was at ~97% util with only ~1.3 GiB free, so the
    # headroom is reinvested as deeper prefix-cache / effective-window depth for
    # the single sequence. +0.5 GiB (5.5 -> 6.0 GiB) is a deliberately
    # CONSERVATIVE first claim: the batched-tokens drop + the removed batch-2
    # graph alone exceed 0.5 GiB before counting the halved GDN state, so this
    # stays comfortably under what 1 seq frees and cannot trip the 0.92 startup
    # gate (which refuses to boot rather than OOM-after-load). To claim the rest:
    # deploy, read the engine's "Available KV cache memory: X GiB" / gpu_worker
    # free-VRAM-after-profiling line, and raise this pin by the measured remainder.
    # One max-length 163840 sequence = 58 blocks + 15 GDN state; the 5.5 GiB pool
    # already reported ~1.44x concurrency at full length (a single full-window
    # request was the practical ceiling), so the extra blocks serve the prefix
    # cache / offload tier, not single-request capacity.
    # 32 GiB of host RAM is a pinned CPU tier (native OffloadingConnector) for
    # evicted prefix-cache blocks. Upstream #45268 reports sleep mode + native
    # offload crashing after a wake; if that hits, drop kvOffloadingSize.
    kvCacheMemory = 6442450944;
    kvOffloadingSize = 32;
    maxModelLen = "163840";
    maxNumSeqs = "1";
    # 2912 = 1 x 2848-token block (mamba align mode cuts prefill chunks to block multiples) + 64 slots for this seq's MTP decode tokens.
    # --mamba-ssm-cache-dtype float32: keep the GDN (Gated DeltaNet) recurrent
    #   state in fp32 rather than letting it fall to the model dtype. This is
    #   NVIDIA's own SGLang recipe for Qwen3.8-27B (--mamba-ssm-dtype float32)
    #   and the long-context fidelity knob measured in the adrienbrault 5090
    #   bundle: fp32 vs bf16 state is 0.05-0.1 top-1 points, and the recurrence
    #   summarizes the whole 163K window, so the state precision -- not the KV
    #   dtype -- sets the long-context quality floor. Cheap: the SSM state is a
    #   fixed-size per-sequence matrix, not per-token KV.
    # NOTE: do NOT enable FlashInfer autotune (--kernel-config
    #   enable_flashinfer_autotune / VLLM_FLASHINFER_AUTOTUNE) with MTP + nvfp4
    #   KV on sm120: upstream (vllm#46329, chengye75-star) found the autotune
    #   benchmark can land inside CUDA-graph capture and deterministically
    #   crash the boot ("operation not permitted when stream is capturing").
    #   We leave it off (the default), which is why it is absent here.
    extraArgs = "--enable-prefix-caching --language-model-only --linear-backend cutlass --reasoning-parser qwen3 --tool-call-parser qwen3_xml --enable-auto-tool-choice --mamba-ssm-cache-dtype float32 --max-num-batched-tokens 2912 --speculative-config '{\"method\":\"mtp\",\"num_speculative_tokens\":3}'";
  };

  # Dormant native disaster-recovery fallback reusing the same patched pkgsAccel.vllm
  # as the coder (replaces the retired stock-image docker-vllm-5090 container).
  # wantedBy = [ ] (the autoStart=false analog); binds the same 127.0.0.1:8010 so it
  # conflicts with the coder. Operator-started only.
  systemd.services.vllm-5090-fallback = mkVllmService {
    model = coderCheckpoint;
    servedModel = "qwen3.8-27b-nvfp4";
    leaseWrap = true;
    conflicts = [ "vllm.service" ];
    wantedBy = [ ];
    gpuMemoryUtilization = "0.75";
    maxModelLen = "24576";
    maxNumSeqs = "1";
    extraArgs = "--language-model-only --reasoning-parser qwen3 --tool-call-parser qwen3_xml --enable-auto-tool-choice --mamba-ssm-cache-dtype float32";
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

  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    home = "/var/lib/vllm";
    createHome = true;
  };

  users.groups.vllm = {};
}
