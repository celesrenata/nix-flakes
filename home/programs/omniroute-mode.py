#!/usr/bin/env python3
"""Tiered, capacity-aware OmniRoute policy. Preview by default; apply with backups and drift checks."""
import argparse
import copy
import datetime as dt
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.error
import urllib.request

# Non-zero entries enable a target for the category. Tier-1 Qwen execution is
# strict priority: 5090 first, M5 MLX second, and 4070 last. Planning is kept
# on the M5 DS4 GLM specialist; the Qwen targets are coding-oriented and must
# not be used as planner fallbacks.
WEIGHTS = {
    'code': (55, 24, 21, 0), 'tester': (55, 24, 21, 0), 'reviewer': (52, 23, 20, 5),
    'planner': (0, 0, 0, 100), 'long': (44, 19, 17, 20), 'research': (44, 19, 17, 20),
    'fast': (55, 24, 21, 0), 'tiny': (55, 24, 21, 0), 'reader': (50, 21, 19, 10),
    'any': (52, 23, 20, 5), 'frontier': (44, 19, 17, 20),
}
CONNECTIONS = {
    'vllm': 'e9bd13fb-c6b6-4c18-b42f-3395266348ce',
    'ollama-local': 'b20e0770-3e14-40c1-87cd-85c34b34381a',
    'llama-cpp': '70b82fc9-6f96-41ac-aa16-8da6099dd7ac',
    'mistral': '9a8095cb-3d53-4327-8c11-5f81f0f904fe',
    'bedrock': 'd4a9a6e4-d054-498a-8fde-aa35dc4dc506',
    'xai': 'b0c69392-b661-44d5-9a35-fabf47d5569b',
}
QWEN5090 = 'vllm/qwen3.8-27b-nvfp4'
IQ3 = 'ollama-local/qwen3.8:27b-iq3-code144k'
MLX = 'llama-cpp/mlx-qwen3.8-27b-4bit'
GLM = 'llama-cpp/ds4-glm53'
# Dedicated 9B reader model (NOT a coder): the 4070 Ti Super ollama reader.
READER4070 = 'ollama-local/qwen3.5-reader:9b'
# Fast tier little coder: 4070 Ti Super ollama 9B (vision + agentic programming / code reading).
FAST9B = 'ollama-local/LisyNeko/qwen3.8-9b-coder:latest'
# Per-category tier-1 target overrides. Categories NOT listed here keep the shared
# [5090/MLX/IQ3/GLM] slot layout driven by WEIGHTS (minimal blast radius: only
# reader + code + tester are retargeted). Each entry is an ordered priority chain
# [(model, weight), ...]; list order is the priority order (tier-1 strategy = priority).
TIER1_OVERRIDES = {
    # Root-cause fix: the reader category previously inherited the CODER models.
    # Serve the dedicated 9B reader instead: the 4070 Ti Super ollama reader.
    'reader': [(READER4070, 100)],
    # Coder chain: 5090 Qwen3.8 NVFP4 (131072) -> m5max GLM-5.3 (speed-first overflow)
    # -> 4070 Ti Super Qwen3.8 IQ3 (147456, unchanged). Replaces MLX with GLM in the
    # local priority chain for code + tester only (reviewer keeps its own GLM blend).
    # 27B fan-out (job1->5090, job2->4070Ti, job3->5090): weighted 2:1 across the two
    # local 27B GPUs. GLM is a dedicated job-4 overflow step in the code/tester root
    # chains (after this pool, before the free/low-cost cloud tiers), not inline here.
    # Round-robin [5090, 4070, 5090] gives a deterministic 2:1 interleave (job1->5090,
    # job2->4070, job3->5090) instead of the old weighted RANDOM draw, which bunched
    # 3+ consecutive 5090 picks. The 5090 appears twice so the cyclic counter yields
    # two 5090 per one 4070 without ever starving the 4070 (weight is a tie-break only).
    'code': [(QWEN5090, 1), (IQ3, 1), (QWEN5090, 1)],
    'tester': [(QWEN5090, 1), (IQ3, 1), (QWEN5090, 1)],
    # Fast chain: new little 9B coder primary -> one slot of the UNCHANGED 5090 27B as
    # overflow (priority order; weights are tie-break, the 5090 keeps its own role/model).
    'fast': [(FAST9B, 70), (QWEN5090, 30)],
}
# Admission checks the uncompressed conversation. Zoo resends its complete
# task transcript, so the raw prompt can exceed 256K even though chatCore then
# compacts it well below the selected model's real 147K/163K context.
# Each physical GPU has one target. The old balanced/full names were two aliases
# for the 5090's single request slot and inflated its share in round robin.
RAW_HYBRID_WINDOW = 524288
PLANNER_RAW_WINDOW = 1048576
POLICIES = {
    QWEN5090: {'capacityUnits': 1, 'maxInputTokens': RAW_HYBRID_WINDOW},
    IQ3: {'capacityUnits': 1, 'maxInputTokens': RAW_HYBRID_WINDOW},
    MLX: {'capacityUnits': 1, 'maxInputTokens': RAW_HYBRID_WINDOW},
    GLM: {'capacityUnits': 1, 'maxInputTokens': RAW_HYBRID_WINDOW},
}
# Policies for the overridden tier-1 pools. Kept OUT of the shared POLICIES map so
# untouched categories (reviewer/fast/tiny/...) that deep-copy POLICIES wholesale
# do not gain extra weightedTargetPolicies keys (which would drift their live combos).
OVERRIDE_POLICIES = {
    QWEN5090: {'capacityUnits': 1, 'maxInputTokens': RAW_HYBRID_WINDOW},
    IQ3: {'capacityUnits': 1, 'maxInputTokens': RAW_HYBRID_WINDOW},
    GLM: {'capacityUnits': 1, 'maxInputTokens': RAW_HYBRID_WINDOW},
    READER4070: {'capacityUnits': 1, 'maxInputTokens': RAW_HYBRID_WINDOW},
    FAST9B: {'capacityUnits': 1, 'maxInputTokens': RAW_HYBRID_WINDOW},
}

# Categories whose cloud (tier 2+) overflow is restricted to FREE online providers only,
# regardless of the active mode. 'fast' must never spend money: it overflows past local
# capacity only to the free set (:free models + Mistral free-allowance), never paid Bedrock/OpenAI.
FREE_ONLY_CLOUD_CATEGORIES = {'fast'}
# Per-category tier-1 concurrencyPerModel. Default is 1 (one in-flight request per
# device, the cross-lane arbiter default). 'fast' runs 2 per member -> 2 on the 5090 +
# 2 on the 4070 Ti Super 9B = 4 concurrent fast requests. NOTE: the 5090 vllm provider
# cap is maxConcurrent 2 (esnixi/vllm.nix --max-num-seqs 2), shared with the coder, so
# fast can consume both 5090 slots and compete with code for the card.
TIER1_CONCURRENCY = {'fast': 2}
def is_free_cloud(model):
    return model.endswith(':free') or model in ('mistral/codestral-latest', 'mistral/mistral-code-latest')
# Existing, verified provider model IDs. Never derive credit tiers from rounded display names.
CLOUD = {
    # OpenRouter free requests share a daily account quota; changing model IDs
    # cannot restore capacity after that quota is exhausted. Codestral has a
    # separate free allowance and supports tool calls. Kiro is excluded from all routes.
    # Direct OpenAI is pay-as-you-go: keep it out of tiers 2-4 (Bedrock serves the same
    # GPT-5.6 models) and only as low-weight tier-5 routes. Opus 5.5 needs the
    # global/us inference profile; the bare anthropic.claude-opus-5-5 ID is rejected.
    2: [('mistral/codestral-latest', 25), ('mistral/mistral-code-latest', 25),
        ('bedrock/global.openai.gpt-5.6-luna', 50)],
    3: [('bedrock/global.openai.gpt-5.6-terra', 60), ('bedrock/global.xai.grok-4.6', 40)],
    4: [('bedrock/global.anthropic.claude-opus-5-5', 40), ('bedrock/global.openai.gpt-5.6-sol', 35),
        ('bedrock/us.anthropic.claude-sonnet-4-6', 25)],
    5: [('bedrock/global.anthropic.claude-opus-5-5', 40), ('bedrock/global.openai.gpt-5.6-sol', 25),
        ('xai/grok-4.6', 15), ('openai/gpt-5.6-terra', 10), ('openai/gpt-5.6-sol', 10)],
}
MODES = {
    'local-only': ([1], 1),
    'local-free': ([1, 2], 2),
    'tier-2': ([1, 2], 2),  # Free Mistral models plus low-cost ChatGPT.
    'local-light-paid': ([1, 2, 3], 3),
    'local-openai-bedrock-grok': ([1, 2, 3, 4, 5], 5),
    'openai-bedrock-grok-local': ([2, 3, 4, 5, 1], 5),
    'gas': ([5, 4, 3, 2, 1], 5),
    'tiered': ([1, 2, 3, 4, 5], 5),
}
FIELDS = ('name', 'description', 'strategy', 'models', 'config', 'context_length', 'context_cache_protection')
OBSOLETE = {'healthCheckEnabled', 'healthCheckTimeoutMs', 'timeoutMs', 'queueDepth'}
# Shared GPU pool: each connection's maxConcurrent is OmniRoute's persisted
# per-device semaphore, the cross-lane arbiter so code/research/planner don't
# over-dispatch the same card. 5090 vLLM runs 2 sequences (esnixi/vllm.nix
# --max-num-seqs 2; the 2nd slot is slow overflow). 4070 Ti Super ollama caps
# at 4 (its 9B capacity); ollama's own NUM_PARALLEL/MAX_QUEUE gates the 27B
# down to 1 and spills. M5 GLM is a single slot. (M5 reader connection retired.)
PROVIDER_POLICIES = {
    CONNECTIONS['vllm']: {'maxConcurrent': 2},
    CONNECTIONS['ollama-local']: {'maxConcurrent': 4},
    # Both M5 models share the mutually-exclusive local-model-proxy.
    CONNECTIONS['llama-cpp']: {'maxConcurrent': 1},
}

def request(base, path, data=None, method=None):
    verb = method or ('PUT' if data is not None else 'GET')
    command = ['curl', '--fail-with-body', '--silent', '--show-error', '--max-time', '45',
        '-X', verb, '-H', 'Content-Type: application/json', base.rstrip('/') + path]
    api_key = os.environ.get('OMNIROUTE_API_KEY')
    if api_key:
        command.extend(['-H', 'Authorization: Bearer ' + api_key])
    payload = None
    if data is not None:
        command.extend(['--data-binary', '@-'])
        payload = json.dumps(data).encode()
    result = subprocess.run(command, input=payload, capture_output=True)
    if result.returncode:
        detail = (result.stdout + result.stderr).decode(errors='replace')[:1500]
        raise RuntimeError(f'{verb} {path}: curl {result.returncode}: {detail}')
    return json.loads(result.stdout)

def live_combos(base):
    result = {}
    offset = 0
    while True:
        listing = request(base, f'/api/combos?limit=100&offset={offset}')
        rows = listing['combos']
        result.update({x['name']: x for x in rows})
        offset += len(rows)
        if not rows or offset >= listing.get('total', offset): return result

def projection(combo):
    if not combo: return None
    result = {key: copy.deepcopy(combo[key]) for key in FIELDS if key in combo}
    # PUT strips this legacy field. Weighted execution enforces zero queuing itself.
    if isinstance(result.get('config'), dict): result['config'].pop('queueDepth', None)
    return result

def config_for(before, **overrides):
    config = {k: v for k, v in (before or {}).get('config', {}).items() if k not in OBSOLETE}
    # Remove incompatible prior strategy features; all new roots have explicit tier order.
    for key in ('compositeTiers', 'evalRouting', 'tierRouting', 'weightedTargetPolicies', 'weightedRoundRobin'):
        config.pop(key, None)
    config.update(disableSessionStickiness=True, stickyRoundRobinLimit=1, maxRetries=0,
        queueTimeoutMs=1000, targetTimeoutMs=600000, trackMetrics=True)
    config.update(overrides)
    return config

def model_step(category, tier, index, model, weight):
    provider = model.split('/')[0]
    result = {'id': f'{category}-t{tier}-{index}', 'kind': 'model', 'model': model, 'providerId': provider, 'weight': weight}
    if provider in CONNECTIONS: result['connectionId'] = CONNECTIONS[provider]
    return result

def allowed_cloud(mode, model):
    if mode == 'local-free':
        return model.endswith(':free') or model in ('mistral/codestral-latest', 'mistral/mistral-code-latest')
    if model.startswith('kiro/'):
        return False
    return True

def build(mode, existing):
    order, ceiling = MODES[mode]
    plan = {}
    for category, (vllm, iq3, mlx, glm) in WEIGHTS.items():
        # Inactive tiers stay installed for inspection, but roots only reference permitted pools.
        for tier in range(1, 6):
            name = f'pool/tier{tier}/{category}'
            if tier == 1 and category in TIER1_OVERRIDES:
                # Retargeted tier-1 chain (reader/code/tester): use the explicit
                # per-category model set instead of the shared [5090/MLX/IQ3/GLM] slots.
                targets = list(TIER1_OVERRIDES[category])
            else:
                targets = [(QWEN5090,vllm), (MLX,mlx), (IQ3,iq3), (GLM,glm)] if tier == 1 else CLOUD[tier]
            targets = [(model, weight) for model, weight in targets if weight > 0]
            if tier != 1:
                targets = [(m,w) for m,w in targets if not m.startswith('kiro/')]
                if tier in order: targets = [(m,w) for m,w in targets if allowed_cloud(mode,m)]
                if category in FREE_ONLY_CLOUD_CATEGORIES: targets = [(m,w) for m,w in targets if is_free_cloud(m)]
            if not targets: continue
            if tier == 1 and category in TIER1_OVERRIDES:
                # Only publish policies for the models actually in this overridden pool.
                target_policies = {model: copy.deepcopy(OVERRIDE_POLICIES[model]) for model, _ in targets}
            else:
                target_policies = copy.deepcopy(POLICIES)
            if category == 'planner':
                for policy in target_policies.values():
                    policy['maxInputTokens'] = PLANNER_RAW_WINDOW
            # code/tester tier-1 interleave the two 27B GPUs via deterministic round-robin
            # (cyclic counter over [5090, 4070, 5090]); every other tier-1 pool keeps strict priority.
            rr_gpu_pool = tier == 1 and category in ('code', 'tester')
            strategy = 'round-robin' if rr_gpu_pool else ('priority' if tier == 1 else 'round-robin')
            if tier == 1 and category == 'planner':
                description = 'Tier 1 planner: M5 DS4 GLM only'
            elif tier == 1 and category == 'reader':
                description = 'Tier 1 reader: 4070 Ti Super 9B ollama reader'
            elif tier == 1 and category in TIER1_OVERRIDES:
                description = (f'Tier 1 {category}: 5090 Qwen3.8 / 4070 Qwen3.8 IQ3 round-robin 2:1 interleave + session sticky'
                               if category in ('code', 'tester')
                               else f'Tier 1 {category}: 5090 Qwen3.8 > M5 GLM > 4070 Qwen3.8 IQ3 priority')
            elif tier == 1:
                description = f'Tier 1 {category}: 5090 > M5 MLX > 4070 Qwen priority'
            else:
                description = f'Tier {tier} {category}: capacity-aware weighted round robin'
            plan[name] = {'name': name, 'description': description,
                'strategy': strategy, 'models': [model_step(category,tier,i,m,w) for i,(m,w) in enumerate(targets)],
                'context_length': (PLANNER_RAW_WINDOW if category == 'planner' else 163840) if tier == 1 else 1000000,
                'context_cache_protection': False,
                'config': config_for(existing.get(name), concurrencyPerModel=(TIER1_CONCURRENCY.get(category, 1) if tier == 1 else 4),
                    **({'weightedRoundRobin': tier != 1} if not rr_gpu_pool else {}),
                    # GPU round-robin pools keep sessions pinned to their warm card (KV-cache reuse: ~6x on follow-up turns),
                    # so NEW sessions interleave 5090/4070 while a continuing conversation does not re-prefill on the other GPU.
                    **({'disableSessionStickiness': False} if rr_gpu_pool else {}),
                    **({'weightedTargetPolicies': target_policies} if (tier == 1 and not rr_gpu_pool) else {}))}
    # Dedicated GLM job-4 overflow pools for the weighted 27B coder categories. GLM
    # is a separate escalation step (NOT inline in the tier-1 weighted pool), referenced
    # as a combo-ref by the local/hybrid roots after tier 1 and before any cloud tier.
    for category in ('code', 'tester'):
        name = f'pool/tier1b/{category}'
        plan[name] = {'name': name,
            'description': f'{category.capitalize()} high-context overflow: GLM-5.3 1M local before cloud',
            'strategy': 'priority',
            'models': [model_step(category, '1b', 'glm', GLM, 100)],
            'context_length': PLANNER_RAW_WINDOW,
            'context_cache_protection': False,
            'config': config_for(existing.get(name), concurrencyPerModel=1, queueTimeoutMs=15000)}
    # Pools exist before any root points at them. Direct local category routes share the same physical reservations.
    for category in WEIGHTS:
        for family in ('local', 'hybrid'):
            name = f'{family}/{category}'
            tiers = [1] if family == 'local' else order
            refs = [t for t in tiers if f'pool/tier{t}/{category}' in plan]
            plan[name] = {'name': name, 'description': f'{category} routing: {mode if family == "hybrid" else "local-only"}; per-task X-OmniRoute-Tier',
                'strategy': 'priority', 'models': ([{'id': f'{family}-{category}-tier{t}', 'kind': 'combo-ref', 'comboName': f'pool/tier{t}/{category}', 'weight': 0} for t in refs] if category not in ('code', 'tester') else ([{'id': f'{family}-{category}-tier1', 'kind': 'combo-ref', 'comboName': f'pool/tier1/{category}', 'weight': 0}] + ([{'id': f'{family}-{category}-tier1b', 'kind': 'combo-ref', 'comboName': f'pool/tier1b/{category}', 'weight': 0}] if 1 in refs else []) + [{'id': f'{family}-{category}-tier{t}', 'kind': 'combo-ref', 'comboName': f'pool/tier{t}/{category}', 'weight': 0} for t in refs if t != 1])),
                'context_length': 163840 if (family == 'local' or category == 'fast') else 262144, 'context_cache_protection': False,
                'config': {k:v for k,v in config_for(existing.get(name), nestedComboMode='execute',
                    tierRouting={'defaultTier': 1, 'maximumTier': ceiling if family == 'hybrid' else 1}).items() if k != 'queueDepth'}}
    return plan

def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temp = path.with_name(path.name + '.tmp')
    temp.write_text(json.dumps(data, indent=2) + '\n');temp.chmod(0o600);temp.replace(path)

def same(expected, actual):
    # API normalization can add metadata, but must retain every requested field/value.
    if isinstance(expected, dict): return isinstance(actual, dict) and all(k in actual and same(v,actual[k]) for k,v in expected.items())
    if isinstance(expected, list): return isinstance(actual,list) and len(expected)==len(actual) and all(same(a,b) for a,b in zip(expected,actual))
    return expected == actual

def assert_expected(expected, live):
    changed = [name for name, record in expected.items() if projection(live.get(name)) != projection(record)]
    if changed: raise RuntimeError('Routing drift; inspect before changing: ' + ', '.join(changed))

def persist(base, name, desired, current):
    if current:
        fresh = request(base, '/api/combos/' + current['id'])
        if projection(fresh) != projection(current): raise RuntimeError('Concurrent edit: ' + name)
        request(base, '/api/combos/' + current['id'], desired)
        actual = request(base, '/api/combos/' + current['id'])
    else:
        actual = request(base, '/api/combos', desired, 'POST')
    if not same(desired, actual): raise RuntimeError('Readback mismatch: ' + name)
    return actual

def apply_plan(base, state_path, state, live, plan, mode, providers):
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = state_path.parent / (stamp + '-tier-policy-before.json')
    record = {'previous_mode': state.get('active_mode', 'custom'), 'next_mode': mode,
        'before': {name: live.get(name) for name in plan}, 'after': {},
        'provider_before': {ident: change['before'] for ident, change in providers.items()},
        'provider_after': {ident: change['after'] for ident, change in providers.items()}}
    write_json(backup, record)
    changed=[]
    provider_touched=[]
    try:
        # Fail before mutating any route if the provider changed after preview.
        for ident, change in providers.items():
            connection=request(base, '/api/providers/' + ident)['connection']
            current={key: connection.get(key) for key in change['before']}
            if not same(current, change['before']): raise RuntimeError('Provider changed concurrently: ' + change['name'])
        for name, desired in plan.items():
            current = live.get(name)
            if same(desired, current):
                record['after'][name] = projection(current);continue
            actual = persist(base, name, desired, current)
            changed.append(name);live[name]=actual;record['after'][name]=projection(actual)
            write_json(backup,record)
        for ident, change in providers.items():
            if same(change['before'], change['after']): continue
            provider_touched.append(ident)
            request(base, '/api/providers/' + ident, change['after'])
            connection=request(base, '/api/providers/' + ident)['connection']
            actual={key: connection.get(key) for key in change['after']}
            if not same(actual, change['after']): raise RuntimeError('Provider readback mismatch: ' + change['name'])
            write_json(backup,record)
        state = {'version':2, 'active_mode':mode, 'last':record['after'],
            'providers':record['provider_after'], 'last_backup':str(backup)}
        write_json(state_path,state)
    except Exception:
        for ident in reversed(provider_touched):
            change=providers[ident]
            connection=request(base, '/api/providers/' + ident)['connection']
            current={key: connection.get(key) for key in change['after']}
            if same(current, change['after']): request(base, '/api/providers/' + ident, change['before'])
        # Restore modified parents first. Keep newly-created, unreferenced pools for inspection.
        for name in reversed(changed):
            before=record['before'][name]
            if before:
                current=request(base,'/api/combos/'+live[name]['id'])
                if projection(current)==record['after'].get(name): persist(base,name,projection(before),current)
        print('Apply failed; unchanged modified routes restored. Backup:',backup,file=sys.stderr)
        raise
    print(f'Applied {len(changed)} changes; {len(plan)} routes verified. Backup: {backup}')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('preset',nargs='?',choices=MODES)
    parser.add_argument('--apply',action='store_true')
    parser.add_argument('--list',action='store_true')
    parser.add_argument('--status',action='store_true')
    parser.add_argument('--baseline',type=Path,help='Reviewed complete live-combo snapshot for the first migration')
    parser.add_argument('--rollback',type=Path)
    parser.add_argument('--plan-file',type=Path)
    parser.add_argument('--base-url',default=os.environ.get('OMNIROUTE_MANAGEMENT_URL','https://omniroute.celestium.life'))
    parser.add_argument('--state-dir',type=Path,default=Path.home()/'.local/state/omniroute-routing')
    args=parser.parse_args()
    if args.list:
        for name,(order,ceiling) in MODES.items(): print(name, ' > '.join('Tier '+str(t) for t in order), 'ceiling',ceiling)
        return
    state_path=args.state_dir/'tier-switch-state.json'
    state=json.loads(state_path.read_text()) if state_path.exists() else {}
    live=live_combos(args.base_url)
    if args.rollback:
        record=json.loads(args.rollback.read_text());assert_expected(record['after'],live)
        provider_after=record.get('provider_after',{})
        for ident, expected in provider_after.items():
            connection=request(args.base_url, '/api/providers/' + ident)['connection']
            current={key: connection.get(key) for key in expected}
            if not same(current, expected): raise RuntimeError('Provider drift; refusing rollback: ' + ident)
        print('Restore',record['previous_mode'],'from',args.rollback)
        if args.apply:
            for name in reversed(list(record['before'])):
                before=record['before'][name]
                if before: live[name]=persist(args.base_url,name,projection(before),live.get(name))
            for ident, before in record.get('provider_before',{}).items():
                request(args.base_url, '/api/providers/' + ident, before)
                connection=request(args.base_url, '/api/providers/' + ident)['connection']
                if not same({key: connection.get(key) for key in before}, before): raise RuntimeError('Provider rollback readback mismatch: ' + ident)
            # Newly-created unused pools remain available; no histories are deleted.
            restored={n:projection(live[n]) for n in record['before'] if record['before'][n]}
            write_json(state_path,{'version':2,'active_mode':record['previous_mode'],'last':restored})
        return
    if state: assert_expected(state['last'],live)
    elif args.baseline:
        baseline={x['name']:projection(x) for x in json.loads(args.baseline.read_text())}
        plan_names=set(build(args.preset or 'tiered',live))
        assert_expected({n:baseline.get(n) for n in plan_names},live)
    elif args.apply: raise RuntimeError('First apply requires --baseline with the reviewed pre-migration snapshot')
    if args.status:
        print('Active preset:',state.get('active_mode','not migrated'));print('Verified managed routes:',len(state.get('last',{})));return
    if not args.preset: parser.error('Choose a preset, --list, --status or --rollback')
    plan=build(args.preset,live)
    providers={}
    for ident, patch in PROVIDER_POLICIES.items():
        connection=request(args.base_url, '/api/providers/' + ident)['connection']
        providers[ident]={'name':connection.get('name'),
            'before':{key:connection.get(key) for key in patch}, 'after':patch}
    order, ceiling = MODES[args.preset]
    print('Preset:',args.preset,'; tier order:',order,'; maximum:',ceiling)
    for c,w in WEIGHTS.items(): print(f'{c}: local priority 5090/M5-MLX/4070/M5-DS4; enabled weights {w[0]}/{w[2]}/{w[1]}/{w[3]}; active tier ceiling {ceiling}')
    for tier,targets in CLOUD.items():
        if tier in order:
            print('Tier',tier,':',', '.join(f'{m} ({w})' for m,w in targets if allowed_cloud(args.preset,m)))
    print('5090 MTP: one 131072-context request (fixed kvCacheMemory ~4.45 GiB). 4070 IQ3: one 147456-context request. M5 MLX: 131072; M5 DS4: 163840; one shared slot.')
    changes=sum(not same(v,live.get(n)) for n,v in plan.items())
    provider_changes=sum(not same(change['before'],change['after']) for change in providers.values())
    for change in providers.values():
        print('Provider',change['name'],': maxConcurrent',change['before'].get('maxConcurrent'),'->',change['after'].get('maxConcurrent'))
    print('Changes:',changes,'routes and',provider_changes,'provider settings; routes:',len(plan))
    if args.plan_file: write_json(args.plan_file,plan)
    if args.apply: apply_plan(args.base_url,state_path,state,live,plan,args.preset,providers)
    else: print('Dry run. Add --apply to apply this policy.')

if __name__=='__main__':
    try: main()
    except (OSError,ValueError,KeyError,RuntimeError) as error:
        print('ERROR:',error,file=sys.stderr);sys.exit(1)
