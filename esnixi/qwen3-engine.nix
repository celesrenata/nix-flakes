{ config, lib, pkgs, pkgsAccel, ... }:

# qwen3-engine.nix -- the mkyt/qwen3-27b-5090 bespoke C++/CUDA engine
# (libq27.so + its HTTP server) as a SELECTABLE alternative to the vLLM coder.
#
# Why it exists: on one RTX 5090 (SM120) it benchmarks ~2-2.8x vLLM single-
# request decode and holds a 605K-token KV pool / full 262144 context, on the
# same gdnfp4 weights + NVFP4 KV + DFlash2 the vLLM coder uses. This unit lets
# you A/B it against the vLLM coder on real agent tasks and keep whichever wins.
#
# It is DEFAULT OFF (my.engines.qwen3Native.enable = false): vLLM stays the
# primary coder, OmniRoute/Menagerie and the rollback generation are untouched,
# until you deliberately flip the knob and benchmark. When enabled it:
#   * serves the OpenAI/Anthropic API on 127.0.0.1:8010 under the served name
#     "qwen3.8-27b-nvfp4" -- the SAME port + identity the vllm-switcher and
#     OmniRoute expect, so it is a drop-in for the vLLM coder on the wire;
#   * takes the shared 5090 via the same gpu_launch.py flock lease as vLLM,
#     BEFORE loading CUDA weights, and conflicts with vllm.service (one engine
#     owns the card at a time);
#   * runs text-only (VISION=off) to match the --language-model-only vLLM coder
#     -- the vision container (port 8011) is unchanged and still handles images;
#   * reads the gdnfp4 weights + DFlash2 draft from the vLLM model dir.
#
# The frontend's API server is required (it is the only way to drive libq27.so,
# which is a ctypes C-ABI library, not a server); it is run with the minimum
# env it needs and nothing more.

let
  cfg = config.my.engines.qwen3Native;
  engine = pkgsAccel.qwen3-27b-5090-engine;
  share = "${engine.passthru.libq27}/share/qwen3-27b-5090";
  frontendPython = engine.passthru.frontendPython;

  # Same flock-lease wrapper + runtime helpers the vLLM unit and the vision
  # container use: take an exclusive flock on the 5090 lock, mark the fd
  # inheritable, then exec the server so the kernel releases the lease on exit.
  gpuLaunch = ./gpu_launch.py;

  # CUDA 13.3 runtime libs libq27.so links against (cudart) + the NVIDIA driver.
  ldPath = lib.concatStringsSep ":" [
    "${engine.passthru.libq27}/lib" # libq27.so
    "${pkgs.cudaPackages_13_3.cuda_cudart}/lib"
    "${config.hardware.nvidia.package}/lib"
  ];

  # The frontend puts frontend/, engine/python and reference/ on sys.path.
  pythonPath = lib.concatStringsSep ":" [
    "${share}/frontend"
    "${share}/engine-python"
    "${share}/reference"
  ];
in
{
  options.my.engines.qwen3Native = {
    enable = lib.mkEnableOption ''
      the mkyt/qwen3-27b-5090 native C++/CUDA engine as the 5090 coder, in place
      of vLLM (mutually exclusive with vllm.service). Default off: a benchmark
      candidate, not the production default'';

    maxTokens = lib.mkOption {
      type = lib.types.int;
      default = 163840;
      description = ''
        Context ceiling (MAX_TOKENS). >= the 163840 production baseline; the
        engine lowers it to what the VRAM budget fits (MAX_TOKENS_FIT=1). Set to
        262144 to probe the full native context once the baseline is confirmed.'';
    };

    maxSeqs = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Concurrent requests (MAX_SEQS). 1 matches the single-seq vLLM coder.";
    };

    stateHostCacheGiB = lib.mkOption {
      type = lib.types.int;
      default = 32;
      description = ''
        GiB of pinned host RAM for the prefix cache (STATE_HOST_CACHE) -- GDN
        state checkpoints that let a growing agent conversation / a repeated long
        document restore instead of re-prefilling. One checkpoint is ~144 MiB
        (48-layer fp32 GDN state), so this holds ~GiB*7 checkpoints. Sized for a
        multi-user OmniRoute service (3 people x several agents x deep histories):
        32 GiB (~220 checkpoints) keeps the shared system-prompt/tools prefix and
        many live conversations warm across turns. Pinned (unswappable) host RAM;
        the box has ~103 GiB available, so 32 leaves ample headroom. 0 disables.
      '';
    };

    port = lib.mkOption {
      type = lib.types.str;
      default = "8010";
      description = "Loopback port. 8010 = the vllm-switcher / OmniRoute contract.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The weights dir (gdnfp4 checkpoint + DFlash2 draft) is the vLLM model cache;
    # prefetched out of band, same as the vLLM coder (HF_HUB_OFFLINE at serve).
    systemd.services.qwen3-native-engine = {
      description = "mkyt/qwen3-27b-5090 native engine (primary 5090 coder; served as qwen3.8-27b-nvfp4)";
      after = [ "network.target" "arcane-gpu-lock.service" ];
      requires = [ "arcane-gpu-lock.service" ];
      # Sole 5090 coder (the vllm-switcher was retired; vLLM is kept only as an
      # operator-started rollback fallback). One engine owns the card at a time.
      conflicts = [ "vllm.service" "vllm-5090-fallback.service" ];
      wantedBy = [ "multi-user.target" ];  # autostart: this is the primary coder now

      environment = {
        SERVED_MODEL_NAME = "qwen3.8-27b-nvfp4";
        # gdnfp4 weights + DFlash2 draft resolved by qwen27b.weights from HF cache.
        WEIGHTS = "gdnfp4";
        KV_DTYPE = "nvfp4";
        SPEC = "dflash2";
        Q27_DRAFT_QUANT = "fp4";
        # Text coder: no vision tower (the :8011 container handles images).
        VISION = "off";
        # Prefix cache: GiB of pinned-host GDN-state checkpoints. Upstream
        # compose.yaml defaults this to 4; the engine's INTERNAL default when the
        # var is absent is 0 ("prefix cache off"), which is what the startup log
        # showed ("state cache host 0.000 GiB ... prefix cache off") -> every
        # 107-125K agent-history prompt was fully re-prefilled (cached=0, 13-30s
        # TTFT). Sized up to stateHostCacheGiB (default 32) for the 3-person
        # OmniRoute workload so many deep concurrent conversations stay warm
        # across turns (one checkpoint ~144 MiB; 32 GiB ~= 220 checkpoints).
        STATE_HOST_CACHE = toString cfg.stateHostCacheGiB;
        # Checkpoint stride (upstream default): a checkpoint every 8192 tokens
        # in addition to the message-boundary ones the scheduler plans.
        CHECKPOINT_INTERVAL = "8192";
        MAX_TOKENS = toString cfg.maxTokens;
        MAX_TOKENS_FIT = "1";
        MAX_SEQS = toString cfg.maxSeqs;
        HOME = "/var/lib/vllm";
        HF_HOME = "${config.my.paths.vllmModels}";
        HF_TOKEN_PATH = "${config.sops.secrets.huggingface_token.path}";
        HF_HUB_OFFLINE = "1";
        TRANSFORMERS_OFFLINE = "1";
        PYTHONPATH = pythonPath;
        LD_LIBRARY_PATH = ldPath;
        # q27lib.py's ctypes binding defaults LIB_PATH to the sandbox build dir
        # (/build/engine/libq27.so), which does not exist at runtime; point it at
        # the installed shared object.
        Q27_LIB = "${engine.passthru.libq27}/lib/libq27.so";
        ARCANE_GPU_LOCK = "/run/arcane-gpu/5090.lock";
      };

      path = [ pkgs.bash frontendPython ];

      serviceConfig = {
        Type = "simple";
        User = "vllm";
        Group = "vllm";
        # Acquire the 5090 flock BEFORE server.py imports CUDA/loads libq27.so,
        # then exec the API server bound to the switcher's loopback port.
        ExecStart = ''
          ${pkgs.python3}/bin/python3 ${gpuLaunch} \
            ${frontendPython}/bin/python3 ${share}/frontend/server.py \
            --host 127.0.0.1 --port ${cfg.port} \
            --max-tokens ${toString cfg.maxTokens} \
            --kv-dtype nvfp4 --spec dflash2
        '';
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "120s";
      };
    };

    # Firewall parity with the vLLM coder (loopback only, but the port is already
    # opened by the ai profile; nothing extra needed here).
  };
}
