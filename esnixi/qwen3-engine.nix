{ config, lib, pkgs, inputs, ... }:

# qwen3-engine.nix -- the qwen3-27b-5090 native engine as the 5090 coder.
# Thin wrapper around the upstream flake's NixOS module
# (inputs.qwen27b.nixosModules.qwen27b), applying the machine-specific
# contract: port 8010 (the vllm-switcher / OmniRoute wire identity), the
# gpu_launch.py flock lease, Conflicts=vllm.service, the vllm user, the
# vLLM model dir, and the measured concurrency / KV / prefix-cache values.
#
# The upstream flake (celesrenata/qwen3-27b-5090) builds:
#   engine    -- libq27.so + q27-sfcheck (CUDA 13.3 + CUTLASS v4.8, sm_120a)
#   serve     -- Python 3.12 env (torch, torchvision, transformers, safetensors,
#                numpy, pillow)
#   repoFiles -- the runtime tree (frontend/, engine/python/, reference/)
#
# The flake module defaults follow the upstream README; this wrapper overrides
# them for the esnixi 3-person OmniRoute workload.

let
  cfg = config.my.engines.qwen3Native;

  # The upstream flake's engine packages.
  q27 = inputs.qwen27b.packages."x86_64-linux";

  # Same flock-lease wrapper + runtime helpers the vLLM unit and the vision
  # container use: take an exclusive flock on the 5090 lock, mark the fd
  # inheritable, then exec the server so the kernel releases the lease on exit.
  gpuLaunch = ./gpu_launch.py;
in
{
  # Always import the upstream module. Its `config` is guarded by
  # `services.qwen27b.enable` (the upstream module's own flag), so this is a
  # no-op when we leave that flag unset — the unit is only created when we
  # set `services.qwen27b.enable = true` below (under `cfg.enable`).
  imports = [ inputs.qwen27b.nixosModules.qwen27b ];

  options.my.engines.qwen3Native = {
    enable = lib.mkEnableOption ''
      the qwen3-27b-5090 native C++/CUDA engine as the 5090 coder, in place
      of vLLM (mutually exclusive with vllm.service). Default off: a benchmark
      candidate, not the production default'';

    maxTokens = lib.mkOption {
      type = lib.types.int;
      default = 262144;
      description = ''
        Context ceiling (MAX_TOKENS). The model supports the full 262144-token
        context. MAX_TOKENS_FIT=1 still applies the engine's VRAM-fit check;
        KV admission queues concurrent requests when the fixed pool is full.'';
    };

    maxSeqs = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Concurrent requests (MAX_SEQS). 4 = one slot per OmniRoute user.";
    };

    kvPoolTokens = lib.mkOption {
      type = lib.types.int;
      default = 624896;
      description = ''
        KV_POOL_TOKENS: fixed GPU KV pool size (engine default 0 = fill all free
        VRAM). NOTE the hardware limit: with MAX_TOKENS=262144 and
        MAX_SEQS=4, the per-request KV reservation plus the fixed pool must
        fit under the device budget (~29.52 GiB). The measured reliable
        ceiling under the budget is ~681500 tokens; 624896 (~91% device) is
        the largest fixed pool that boots with a ~0.4 GiB safety margin for
        4 concurrent full-context requests. A fixed KV_POOL_TOKENS overrides
        MAX_TOKENS_FIT auto-shrink, so it must be set below the budget.
        Lower it (e.g. 513216 ~= 83% device) for more free VRAM; 0 restores
        auto-fill (~95%).
      '';
    };

    stateHostCacheGiB = lib.mkOption {
      type = lib.types.int;
      default = 32;
      description = ''
        GiB of pinned host RAM for the prefix cache (STATE_HOST_CACHE) -- GDN
        state checkpoints that let a growing agent conversation / a repeated
        long document restore instead of re-prefilling. One checkpoint is
        ~144 MiB (48-layer fp32 GDN state), so this holds ~GiB*7 checkpoints.
        Sized for a multi-user OmniRoute service (3 people x several agents x
        deep histories): 32 GiB (~220 checkpoints) keeps the shared
        system-prompt/tools prefix and many live conversations warm across
        turns. Pinned (unswappable) host RAM; the box has ~103 GiB available,
        so 32 leaves ample headroom. 0 disables.
      '';
    };

    port = lib.mkOption {
      type = lib.types.str;
      default = "8010";
      description = "Loopback port. 8010 = the vllm-switcher / OmniRoute contract.";
    };
  };

  config = lib.mkIf cfg.enable {

    services.qwen27b = {
      enable = true;
      # Upstream flake packages.
      engine = q27.engine;
      serve = q27.serve;
      files = q27.repoFiles;
      # Machine contract (overrides the flake module's README defaults). The
      # port comes from execStart below (the switcher's loopback port).
      servedModelName = "qwen3.8-27b-nvfp4";
      vision = "off";  # text coder; the :8011 container handles images
      stateHostCacheGiB = cfg.stateHostCacheGiB;
      maxSeqs = cfg.maxSeqs;
      maxTokens = cfg.maxTokens;
      kvPoolTokens = cfg.kvPoolTokens;
      user = "vllm";
      modelPath = config.my.paths.vllmModels;
      # 5090 GPU lease: gpu_launch.py acquires it (via ARCANE_GPU_LOCK) before
      # the server loads CUDA weights, same pattern as the vLLM unit.
      gpuLockFile = "/run/arcane-gpu/5090.lock";
      requires = [ "arcane-gpu-lock.service" ];
      conflicts = [ "vllm.service" "vllm-5090-fallback.service" ];
      extraPath = [ pkgs.python3 ];
      extraEnv = {
        HF_TOKEN_PATH = "${config.sops.secrets.huggingface_token.path}";
        HOME = "/var/lib/vllm";
      };
      # Acquire the 5090 flock BEFORE server.py imports CUDA/loads
      # libq27.so, then exec the API server bound to the switcher's
      # loopback port.
      execStart = ''
        ${pkgs.python3}/bin/python3 ${gpuLaunch} \
          ${q27.serve}/bin/python3 ${q27.repoFiles}/frontend/server.py \
          --host 127.0.0.1 --port ${cfg.port} \
          --max-tokens ${toString cfg.maxTokens} \
          --kv-dtype nvfp4 --spec dflash2
      '';
    };
  };
}
