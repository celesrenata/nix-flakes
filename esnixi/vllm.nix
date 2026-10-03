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

  mkVllmService = { model, servedModel, extraArgs, gpuMemoryUtilization ? "0.79", maxModelLen ? "131072", maxNumSeqs ? "1", kvCacheMemory ? null, kvOffloadingSize ? null, wantedBy ? [ ], conflicts ? [ ], leaseWrap ? false }:
    {
      description = "vLLM OpenAI-compatible API server (${servedModel})";
      after = [ "network.target" ] ++ lib.optionals leaseWrap [ "arcane-gpu-lock.service" ];
      requires = lib.optionals leaseWrap [ "arcane-gpu-lock.service" ];
      inherit wantedBy conflicts;
      environment = vllmEnvironment // lib.optionalAttrs leaseWrap {
        ARCANE_GPU_LOCK = "/run/arcane-gpu/5090.lock";
      };
      path = vllmPath;
      serviceConfig = {
        Type = "simple";
        User = "vllm";
        Group = "vllm";
        # When leaseWrap is set, acquire the shared RTX 5090 flock via gpu_launch.py
        # BEFORE vLLM loads any CUDA weights; gpu_launch.py execs into the command
        # below, and the kernel releases the advisory lock when the process exits.
        ExecStart = "${lib.optionalString leaseWrap "${pkgs.python3}/bin/python3 ${gpuLaunch} "}${pkgsAccel.vllm}/bin/vllm serve ${model} --served-model-name ${servedModel} --host 127.0.0.1 --port 8010 --max-model-len ${maxModelLen} --max-num-seqs ${maxNumSeqs} ${if kvCacheMemory != null then "--kv-cache-memory=${toString kvCacheMemory}" else "--gpu-memory-utilization ${gpuMemoryUtilization}"} --kv-cache-dtype nvfp4 ${lib.optionalString (kvOffloadingSize != null) "--kv-offloading-size ${toString kvOffloadingSize} --kv-offloading-backend native"} ${extraArgs}";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "120s";
      };
    };

  switcherScript = pkgs.writeText "vllm-switch.py" (builtins.readFile ./vllm-switch.py);
  # Shared GPU-lease wrapper (same script the vision container uses): takes an
  # exclusive flock on /run/arcane-gpu/5090.lock, marks the fd inheritable, then
  # execs into vLLM so the kernel releases the lease when the process dies.
  gpuLaunch = ./gpu_launch.py;
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
    conflicts = [ "vllm-reader.service" "vllm-5090-fallback.service" ];
    # The built-in MTP head is substantially faster than DFlash2 on this
    # target while preserving the full production context.
    # 4 concurrent sequences. maxModelLen and maxNumSeqs are COUPLED to vllm-switch.py
    # MODELS["qwen3.8-27b-nvfp4"] and ["qwen3.8-27b-nvfp4-balanced"] (context ==
    # maxModelLen, max_requests == maxNumSeqs); test_vllm_switch.py parses this block
    # and asserts both. Change them together.
    # 6 GiB nvfp4 KV ~= 114 hybrid blocks of 2848 tokens: 4 x ~50K requests, or ~1.8
    # full 131072 contexts. ~2 GiB of the card stays free for the desktop and an idle
    # ComfyUI CUDA context (the lease is exclusive, so Comfy never runs models while
    # this unit holds it).
    # 32 GiB of host RAM is a pinned CPU tier (native OffloadingConnector) for
    # evicted prefix-cache blocks.
    kvCacheMemory = 6442450944;
    kvOffloadingSize = 32;
    maxModelLen = "131072";
    maxNumSeqs = "4";
    # 5760 = 2 x 2848-token blocks (mamba align mode cuts prefill chunks to block multiples) + 64 slots for the other seqs MTP decode tokens.
    extraArgs = "--language-model-only --linear-backend cutlass --reasoning-parser qwen3 --tool-call-parser qwen3_xml --enable-auto-tool-choice --max-num-batched-tokens 5760 --speculative-config '{\"method\":\"mtp\",\"num_speculative_tokens\":3}'";
  };

  # NVFP4 9B reader (AxionML/Qwen3.5-9B-NVFP4, modelopt_fp4 W4A4; vLLM auto-promotes
  # weight-only NVFP4 to W4A16 from the checkpoint config) + NVFP4 KV on SM120.
  # Started ONLY by the switcher (wantedBy = [ ]); mutually exclusive with the coder.
  # --max-model-len 65536 is COUPLED to the switcher MODELS["qwen3.5-9b-nvfp4-reader"]
  # ["context"] in vllm-switch.py — change BOTH together or the readiness poll never
  # matches and the reader tier goes silently dead.
  systemd.services.vllm-reader = mkVllmService {
    model = "AxionML/Qwen3.5-9B-NVFP4";
    servedModel = "qwen3.5-9b-nvfp4-reader";
    leaseWrap = true;
    conflicts = [ "vllm.service" "vllm-5090-fallback.service" ];
    wantedBy = [ ];
    gpuMemoryUtilization = "0.85";
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
      # An idle model used within this many seconds is not evicted for the other unit (the request gets a 409 and goes to the next OmniRoute target).
      VLLM_SWITCH_RESIDENCY_SECONDS = "90";
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

  # Restart-safe idle backstop (independent of the switcher): polls the reader's
  # Prometheus metrics every 60s and stops vllm-reader.service once it has been idle
  # (num_requests_running + num_requests_waiting == 0) for READER_IDLE_SECONDS=300.
  # NOT RuntimeMaxSec (a hard wall-clock cap would kill a long in-flight batch).
  # Runs as root -> needs no sudo. PartOf the reader so a stopped reader has no timer.
  systemd.services.vllm-reader-idle = {
    description = "Stop the NVFP4 reader after it has been idle for 5 minutes";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    path = [ pkgs.curl pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.systemd ];
    script = ''
      set -u
      STATE=/run/vllm-reader-idle.last-nonzero
      IDLE_WINDOW=300
      now=$(date +%s)
      # If the reader is not active, nothing to do (and clear stale state).
      if ! systemctl is-active --quiet vllm-reader.service; then
        rm -f "$STATE" 2>/dev/null || true
        exit 0
      fi
      metrics=$(curl -s --max-time 5 http://127.0.0.1:8010/metrics || true)
      running=$(printf '%s\n' "$metrics" | grep -E '^vllm:num_requests_running' | awk '{print $2}' | head -1)
      waiting=$(printf '%s\n' "$metrics" | grep -E '^vllm:num_requests_waiting' | awk '{print $2}' | head -1)
      # If metrics are unreadable, be conservative: treat as busy (do not stop).
      if [ -z "$running" ] && [ -z "$waiting" ]; then
        echo "$now" > "$STATE"
        exit 0
      fi
      busy=$(awk -v r="''${running:-0}" -v w="''${waiting:-0}" 'BEGIN { print (r+0 > 0 || w+0 > 0) ? 1 : 0 }')
      if [ "$busy" = "1" ]; then
        echo "$now" > "$STATE"
        exit 0
      fi
      # Idle this scrape. Seed the state file if missing so the window starts now.
      if [ ! -f "$STATE" ]; then
        echo "$now" > "$STATE"
        exit 0
      fi
      last=$(cat "$STATE" 2>/dev/null || echo "$now")
      if [ $(( now - last )) -ge "$IDLE_WINDOW" ]; then
        systemctl stop vllm-reader.service || true
        rm -f "$STATE" 2>/dev/null || true
      fi
    '';
  };

  systemd.timers.vllm-reader-idle = {
    description = "Poll the NVFP4 reader for idleness every 60 seconds";
    # partOf stops/restarts the timer with the reader; wantedBy pulls the timer in
    # when the reader starts (partOf alone does not propagate start). Together: the
    # timer runs exactly while the reader is active.
    partOf = [ "vllm-reader.service" ];
    wantedBy = [ "vllm-reader.service" ];
    timerConfig = {
      OnActiveSec = 60;
      OnUnitActiveSec = 60;
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
