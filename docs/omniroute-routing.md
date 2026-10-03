# Local GPU routing and independent Zoo workers

The production gateway is the Kubernetes `omniroute` service. The esnixi MCP
port forward exposes its management API on `127.0.0.1:23128`. The active
capacity-aware tier policy is `home/programs/omniroute-mode.py`; preview it with
`omniroute-mode --status`, preview a preset with `omniroute-mode PRESET`, and apply it with `omniroute-mode PRESET --apply`. It
backs up affected combos under `~/.local/state/omniroute-routing`, refuses
unreviewed drift, and verifies readback. Connection IDs are pinned to this
deployment's existing accounts; provider credentials are untouched.

The same tier pools serve Code, tester, reviewer, planner, long, research, fast,
tiny, reader, any, and frontier tasks. Zoo sends the task's requested tier in
`X-OmniRoute-Tier`. `local/*` routes stay in tier 1; `hybrid/*` routes can
advance through free and paid tiers 2–5 when the active spending mode permits.
Independent tier-1 requests can occupy the three GPU hosts concurrently.
For Code, eligible tier-1 Qwen weights are 5090/4070/M5 = 55/24/21; long and
research reserve 20% for M5 GLM and use 44/19/17 for the Qwen lanes. The two logical 5090 aliases have disjoint input
ranges and share one physical model and request slot. A weighted tier pool
chooses among eligible, available targets; it does not give the 5090 two slots.

- esnixi RTX 5090: Qwen3.8-27B NVFP4, 147456 context, one request slot,
  NVFP4 KV, 80% VRAM cap. Routine Code input is capped at 65536 tokens;
  the long alias admits 65537–114688 input tokens.
- gremlin-1 RTX 4070 Ti Super: Qwen3.8-27B no-MTP IQ3_S, 147456 context,
  one request slot, 114688 input tokens. The 144K test completed with all
  model memory on GPU. The separate `local/4070ti` Ornith route retains
  its 262K context for work suited to that smaller model.
- stabulous M5 Max: GLM-5.3, 163840 context, one slot and up to 147456
  input tokens. Its separate Qwen3.5 reader route uses 32768 context and
  can co-reside with GLM for bounded file reads.

The gremlin IQ3 reprovisioning file is
`home/programs/omniroute-qwen38-4070.Modelfile`. In the Ollama pod, create
`qwen3.8:27b-iq3-code144k` from that file, register it under OmniRoute's
`ollama-local` provider models, set context/input/output overrides to
147456/114688/16384, and sync the gremlin connection before routing traffic.
The older 131K alias remains available in Ollama but is not used by the
managed tier pools. The routing helper checks catalog and connection
prerequisites before applying its legacy flat Code combo.

The active esnixi NixOS generation contains the one-slot vLLM service and
matching switcher, so no temporary runtime drop-in is required. The Zoo
profile import keeps high Code reasoning effort and the 262K hybrid profile
ceiling for cloud fallback; the direct `local/4070ti` profile still selects
Ornith, while tier-1 Code reaches the 144K IQ3 alias through OmniRoute.

Zoo's `new_task` remains the serial parent/child path. The custom build adds an explicit
`parallel_tasks` tool for independent full agents with isolated workspaces, plus a
bounded parallel-read batch for independent read-only calls; edits and commands
remain ordered. The hidden `parallelToolExecution` setting is still not the
mechanism that controls this behavior. Mode switches select saved profiles unless
the workspace's `lockApiConfigAcrossModes` setting locks the parent profile.

Use native `parallel_tasks` first for repository work. The separate
`omniroute-workers` MCP remains useful for parallel analysis when each task is
supplied with all required context and needs no repository tools:

```json
{"tasks":[
  {"id":"implementation","lane":"code","prompt":"Propose the change","context":"Relevant code and requirements"},
  {"id":"tests","lane":"fast","prompt":"Identify boundary cases","context":"Public contract"},
  {"id":"architecture","lane":"long","prompt":"Review consistency with the specification","context":"Relevant specification"}
]}
```

The call returns immediately; use `get_parallel_tasks` with the returned batch ID.
These are concurrent inference workers, not autonomous Zoo children: they cannot
read files, execute tools, or apply patches. The parent collects, validates, and
integrates proposals. Dependent work and conflicting writes remain sequential.
Dedicated local routes keep code/fast/long work on esnixi/gremlin/stabulous,
respectively, without cloud fallback. Separate lane pools avoid a busy code queue
blocking a free M5. Cross-process file locks share 2/1/1 host slots among local MCP
clients. OmniRoute's existing connection caps guard clients on other machines.

Results are held for one hour in the MCP server process. At most six tasks per
batch and twelve active tasks are admitted. Restarting a server loses its batch
results. Cancellation interrupts running jobs at the next streamed event, bounded
by the HTTP timeout. Timing records (without prompts or answers) are appended to
`~/.local/state/omniroute-workers/timings.jsonl`; rotate this file as needed.

Home Manager installs the script and Zoo global routing rule, then merges the MCP
server entry into local and Remote-SSH client settings. The rule is read on new
agent requests; no editor restart or full NixOS rebuild is required for the manual
initial installation. Existing editor profiles and provider secrets are preserved.

The unused `gremlin-4070ti` vLLM connection is disabled: it points at the same
Ollama endpoint as the active Ornith account and otherwise exposes a second
concurrency allowance for the same GPU. The M5 default model is corrected to
`ds4-glm53`. The policy checks connection caps of 2/1/1 and saves only changed
public provider fields in a separate backup.

To undo the gateway changes, restore the `models`, `strategy`, `config`, and
`context_length` fields from the original `*-combos-before.json` using
`PUT /api/combos/<id>`. Strip the obsolete `healthCheckEnabled`,
`healthCheckTimeoutMs`, and `timeoutMs` keys from each restored `config`, as the
current API rejects those legacy fields. For providers, send each entry's
`before` object from `*-providers-before.json` to `PUT /api/providers/<id>`.
Use the earliest combo backup from this review; the later combo backup only
precedes the round-robin stickiness adjustment. These backups contain no
provider credentials. Review intervening edits before restoring whole combos.

To remove the Zoo worker integration, remove only the `omniroute-workers` entry
from the two Zoo MCP settings files and the `~/.roo/rules/30-omniroute-parallel.md`
rule, then reverse the corresponding additions in `home/programs/mcp.nix`.
Keep other user settings and the existing observability MCP entry.


## Per-task tier routing (2026-09-28)

The v2 policy is managed by `omniroute-mode` with presets `local-only`, `local-free`, `tier-2`, `local-light-paid`, `local-kiro`, `kiro-local`, `gas`, and `tiered`. `tier-2` allows local GPUs, free providers, and 0.05× Kiro Qwen3 Coder Next, while excluding tiers 3–5. A tier-2 Zoo request tries the local GPU pool first, then the free/Kiro pool when local capacity or the local attempt cannot serve it. The normal tiered policy uses nested tier pools with capacity-aware smooth weighted round robin; Code uses local weights 65/25/10 (5090/4070/M5), and long/research use 30/10/60. The 5090 Code and long aliases share one physical model and one request slot. M5 GLM has 163840 context. Zoo sends a per-task `X-OmniRoute-Tier` header through its own profile headers, with requested tier/reason persisted in history and displayed in the Task Board. Higher tiers use free/0.05x Kiro, economical paid, Sonnet/moderate, and Opus/high reasoning respectively. Tier 5 includes the verified exact ID `kiro/claude-opus-5.5`. Global presets cap escalation. Existing explicit local profiles remain local.

The prior flat-routing sections above are historical. The legacy `omniroute-routing-policy` entry point delegates to v2 while its state file exists. Inspect with `omniroute-mode --status`, preview with `omniroute-mode PRESET`, then apply an authorized preset using `--apply`. Keep the gateway at one replica until reservations are shared across processes.


## Single-slot 5090 layout (2026-09-28)

The measured 80%-VRAM trial ran Qwen3.8-27B NVFP4 at 147456 context with one request slot, NVFP4 KV, a 256-token prefill batch, and no CPU offload. vLLM allocated a 159952-token KV cache and completed a request. The old two-slot 131072 setting had only 179617 KV tokens in total, so it could not hold two full windows simultaneously. A 180224 context trial at 80% failed because 3.39 GiB KV was required and only 3.00 GiB was available under the current desktop load.

OmniRoute reserves 32768 tokens for output/overhead: 65536 maximum input tokens for the routine Code alias, 114688 for the long alias. Both aliases use the same loaded model and one physical request slot. The 4070 IQ3 is 147456/114688 with one GPU-resident request slot; M5 remains 163840/147456. Hybrid profiles can still escalate to cloud for larger contexts.
