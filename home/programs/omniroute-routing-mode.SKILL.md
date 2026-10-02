---
name: omniroute-routing-mode
description: Inspect or switch OmniRoute's tiered GPU and cloud routing presets, or assign task capability tiers in Zoo. Use for OmniRoute model priorities, spending modes, and per-task tier selection.
---

# OmniRoute routing

The shared switcher runs on esnixi: `ssh esnixi 'omniroute-mode --status'`. Use `--list` for presets. Preview a selected preset with `ssh esnixi 'omniroute-mode PRESET'`, then append `--apply` when the user's request authorizes that preset. The script preserves provider credentials, saves a full backup, detects route/config drift, and verifies readback. If drift is reported, inspect the changed live routes and saved state before reconciling; do not overwrite unrelated changes. `--rollback BACKUP_PATH` previews a restore; `--apply` restores unchanged managed routes from that backup. Created unused pools remain for inspection.

Presets: `local-only` (tier 1), `local-free` (tier 1 plus free targets), `tier-2` (local GPUs, free Mistral, and low-cost ChatGPT; maximum tier 2), `local-light-paid` (tiers 1–3), `local-openai-bedrock-grok` (local then OpenAI/Bedrock/Grok), `openai-bedrock-grok-local` (OpenAI/Bedrock/Grok then local), `gas` (tier 5 down to tier 1), and `tiered` (the normal 1→2→3→4→5 order). Paid targets consume credits. Do not infer a spending-mode change from an observation about speed. The active preset bounds a task's permitted escalation. Kiro AI is excluded from OmniRoute routes because its terms do not permit this use; do not reconnect or restore Kiro targets.

The same five tiers exist for code, tester, reviewer, planner, long, research, fast, tiny, reader, any and frontier:

1. Local GPUs. Comparable Qwen lane weights follow measured warm decode throughput: 5090/4070/M5 = 55/24/21. Long/research reserve 20% for M5 GLM and distribute the remaining share 44/19/17 across those Qwen lanes. The 5090 runs one resident 131072-context Qwen3.8 model with one request slot. The 4070 Qwen3.8 no-MTP IQ3 has one 147456-context slot, fully on GPU. M5 GLM-5.3 has one 163840-context slot. Availability and input size renormalize weights.
2. Free Mistral Codestral and Mistral Code, plus low-cost OpenAI GPT-5.6 Luna. `local-free` filters out the paid ChatGPT target. OpenRouter free models share an account-wide daily cap, so rotating their model IDs cannot restore capacity after that cap is hit.
3. Economical paid OpenAI GPT-5.6 Terra, Bedrock GPT-5.6 Terra, and Bedrock-hosted Grok 4.6.
4. Advanced OpenAI GPT-5.6 Sol, Bedrock GPT-5.6 Sol, and Bedrock Claude Sonnet 4.6.
5. Frontier OpenAI GPT-5.6, Bedrock GPT-5.6 Sol and Claude Opus 5, and official xAI Grok 4.6. These are verified in the current OmniRoute provider catalogs; paid routes consume credits.

Use Zoo's `routing_tier` and `routing_reason` fields on `parallel_tasks` workers or `new_task`. Default to tier 1; choose a higher tier for a task that needs it, including after an inadequate result. `switch_mode` with the current `mode_slug`, a `routing_tier`, and `reason` changes only that chat's tier. Keep Code versus reasoning mode/profile selection and high Code effort. A local-only profile stays local; use the corresponding hybrid profile for cloud tiers. The Task Board shows each chat's requested tier and reason. The request carries `X-OmniRoute-Tier: 1..5`; Tier 2 tries tier 1 local GPUs first, then tier 2 Mistral/low-cost OpenAI capacity on failure or saturation; tiers 3–5 start at the selected tier and try higher permitted tiers. A tier changes provider selection; it does not create concurrency. Dispatch independent work together with `parallel_tasks`.

Implementation and editable weights: [switcher](scripts/omniroute-mode.py). State on esnixi: `~/.local/state/omniroute-routing/tier-switch-state.json`. The scheduler is process-local and production currently runs one gateway replica; multiple replicas require shared reservations before increasing replica count.
