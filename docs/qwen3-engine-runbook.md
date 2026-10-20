# Qwen3.8-27B RTX 5090: native engine (mkyt) vs vLLM — deploy, benchmark, rollback

This is the operator runbook for the "Track B" bespoke C++/CUDA engine
(`mkyt/qwen3-27b-5090`, `libq27.so`) packaged in `overlays/qwen3-27b-5090.nix`
and wired as the default-OFF systemd service in `esnixi/qwen3-engine.nix`.

Everything below needs `sudo` / a running GPU, which the agent could not do.
All of it is yours to run.

## What is already built and verified (no deploy needed to confirm)

- `overlays/qwen3-27b-5090.nix` builds `libq27.so` reproducibly, offline
  (CUTLASS v4.8.0 + engine rev `0594e77c` vendored, verified hashes), sm_120a.
  Output: `nix-build` of `pkgsAccel.qwen3-27b-5090-engine` succeeds.
- The frontend python env is python 3.14 (the SAME interpreter your vLLM torch
  is built for) so it reuses the cached CUDA torch 2.13 — no torch recompile.
- `esnixi/qwen3-engine.nix` adds `my.engines.qwen3Native.enable` (default
  **false**): vLLM stays the production coder until you flip it. When enabled it
  serves `qwen3.8-27b-nvfp4` on `127.0.0.1:8010` (the switcher/OmniRoute
  contract), takes the 5090 flock lease, conflicts with `vllm.service`.

## Track A (already the vLLM default, independent of the engine)

`coderCheckpoint` in `esnixi/vllm.nix` now defaults to
`juzbox/Qwen3.8-27B-NVFP4-GDN` (gdnfp4) — ~7-15% faster vLLM decode at
nvidia-level quality + full tool calls. This is live after your next
`nixos-rebuild switch` regardless of the engine choice.

## 0. Prefetch the weights (once)

Both engines read from the HF cache at `my.paths.vllmModels` with
`HF_HUB_OFFLINE=1`, so fetch ahead of time (revisions pinned in
`qwen27b/weights.py`, surfaced here):

```bash
export HF_HOME=/var/lib/vllm/models   # = config.my.paths.vllmModels
# gdnfp4 target (also the vLLM Track-A default):
huggingface-cli download juzbox/Qwen3.8-27B-NVFP4-GDN \
  --revision 3e686408cf61c2b579c67ab21696c9fc94e41e25
# DFlash2 draft (the engine's SPEC=dflash2 drafter):
huggingface-cli download incoai/Qwen3.8-27B-DFlash2 \
  --revision 015e795645c74b1a0eeef3b570031fb62e769bc5
sudo chown -R vllm:vllm /var/lib/vllm/models
```

## 1. Deploy the build (both engines available; vLLM still primary)

```bash
cd /home/celes/sources/celesrenata/nix-flakes-refactored
sudo nixos-rebuild switch --flake .#esnixi
```

This builds `libq27.so` + the engine (first time: a CUDA compile on the build
hosts) and lands the gdnfp4 vLLM default. The engine service is present but
inactive (default off). Nothing about the vLLM coder/switcher/lease changes.

## 2. Baseline the vLLM coder (gdnfp4, current production shape)

```bash
sudo systemctl restart vllm.service
curl -s http://127.0.0.1:8010/v1/models | jq .
nvidia-smi --query-compute-apps=used_memory --format=csv,noheader   # record
# Agent-task timing (what actually matters): run your real coding-agent
# workload (Menagerie / Claude Code / Codex) against :8010 and record
# wall-clock task completion time, not just tok/s. Repeat 3x.
```

## 3. Switch to the native engine and A/B it

Enable the engine (one line), rebuild, hand it the card:

```nix
# esnixi/vllm.nix or a host module:
my.engines.qwen3Native.enable = true;
```

```bash
sudo nixos-rebuild switch --flake .#esnixi
sudo systemctl stop vllm.service          # the engine conflicts with it anyway
sudo systemctl start qwen3-native-engine.service
journalctl -u qwen3-native-engine -f      # wait for "engine ready"; it prints
                                          # the memory plan + the KV pool size
```

Then run the **same** agent workload against the **same** endpoint
(`127.0.0.1:8010`, served name `qwen3.8-27b-nvfp4` — identical wire contract, so
OmniRoute/agents need no change) and record the same metrics.

The engine's own bench scripts (in its source tree, run from a dev checkout if
you want micro-numbers rather than agent-task time):
`scripts/bench_agentic.py --scenarios decode,agent,longctx`,
`scripts/bench_concurrent.py`, `scripts/bench_decode.py`.

### What to compare (optimize for task completion, not tok/s)
- Wall-clock time for a real multi-turn agent task (the headline metric).
- Time-to-first-token on an agent turn after a 20K+ history (the engine's
  published edge: 0.19s vs vLLM 0.57s).
- KV pool size / max context the server reports at startup (engine: up to
  605K-token pool / full 262144; vLLM: ~173K at 160K ctx).
- Tool-call correctness + reasoning on your tasks (both use gdnfp4 + FP8
  attention, so parity is expected; confirm it).
- VRAM at idle/loaded/decoding (`nvidia-smi`).

## 4. Push context toward 262144 (objective #10) — engine only

Once the 163840 baseline is confirmed, probe the full native context:

```nix
my.engines.qwen3Native.maxTokens = 262144;
```

```bash
sudo nixos-rebuild switch --flake .#esnixi
sudo systemctl restart qwen3-native-engine.service
# MAX_TOKENS_FIT=1 lowers it to what VRAM fits if 262144 doesn't; the startup
# log prints the achieved pool. Needle-retrieval check at depth:
#   scripts/needle_test.py --tokens 190000 --needles 16   (from a dev checkout)
```

## 5. Rollback (always available)

The engine is default-off and conflicts-gated, so rollback is trivial:

```bash
# Fast: just hand the card back to vLLM.
sudo systemctl stop qwen3-native-engine.service
sudo systemctl start vllm.service

# Full: disable the engine in config and rebuild.
#   my.engines.qwen3Native.enable = false;
sudo nixos-rebuild switch --flake .#esnixi

# Nuclear: previous NixOS generation (the whole pre-engine system).
sudo nixos-rebuild switch --rollback
```

To also roll the vLLM checkpoint back off gdnfp4:
`coderCheckpoint = coderCheckpoints.nvidia;` in `esnixi/vllm.nix`, rebuild.

## Decision rule

Keep whichever wins on **real agent-task completion time** with no tool-call /
reasoning regression. If the engine wins decisively (its published numbers
suggest 2-2.8x decode + far larger context), promote it: set
`my.engines.qwen3Native.enable = true` as the host default and flip the switcher
to prefer it. If it's close or has rough edges, the gdnfp4 vLLM coder (Track A)
is already a free win and stays primary. Both are reproducible and both roll
back cleanly.
