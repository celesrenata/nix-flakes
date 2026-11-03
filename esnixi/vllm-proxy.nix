{ ... }:

{
  imports = [ ./vllm.nix ./comfy-worker.nix ./vllm-idle.nix ./qwen3-engine.nix ];

  # The mkyt native engine is the sole 5090 coder (replaced vLLM). The
  # vllm-switcher was retired (Option 2b), so OmniRoute reaches the coder
  # directly on 8010 rather than through the switcher's 8011 front door.
  my.engines.qwen3Native.enable = true;
  # Concurrency 4. KV pool = AUTO-FILL (0), which is the true reliable maximum.
  #
  # The device BUDGET is a hard ceiling (~29.52 GiB, set by an internal reserve,
  # NOT by free VRAM) and a FIXED KV_POOL_TOKENS must fit under it or the engine
  # REFUSES to boot. MEASURED, both refuse even with the whole card free:
  #   - 745472 ("97%") -> 30.670 GiB device pools  (crash-loop)
  #   - 704000         -> 29.919 GiB device pools > 29.52 budget  (crash-loop)
  # From these two points: fixed 17.395 GiB + kv; 704000 tok -> 12.524 GiB kv =>
  # ~56210 KV-tokens/GiB, so the reliable fixed ceiling under a 29.52 budget is
  # only ~681500 tokens -- LESS than auto-fill already takes.
  #
  # Auto-fill (0) sizes against the LIVE budget each boot and landed at 696704
  # tokens / 29.230 GiB device (~93% of the 31.45 GiB card) and boots every
  # time. You cannot pin higher than this and still boot -- the top ~5.5% of the
  # card is engine reserve, and the 31.85 GiB of state checkpoints live in
  # PINNED HOST RAM, not VRAM. "96.5% of the card" for KV is not physically
  # available; 696704 / ~93% is the real max. Leave this at 0.
  #
  # The punt bug is fixed by the per-request CAP, not the pool: the original
  # MAX_TOKENS=262144 let ONE request reserve 262K, so 4 x 262144 (~1.05M)
  # overcommitted the pool ~1.5x and slots 2-4 queued on KV admission (surfaced
  # upstream as punts). maxTokens=163840 is the LARGEST cap that still keeps all
  # four slots co-resident with no KV-admission queueing: 4 x 163840 = 655360 <=
  # the ~696704 auto-fill pool. (2 x 163840 = 327680 leaves ~369K for the other
  # two slots, so two >100K-input jobs co-reside with lots of room.) Going to
  # 262144 would fit only 2 big jobs and re-punt 4 concurrent large jobs, so 4-up
  # concurrency is preserved by capping here.
  my.engines.qwen3Native.maxSeqs = 4;
  my.engines.qwen3Native.maxTokens = 163840;
  my.engines.qwen3Native.kvPoolTokens = 0;

  services.nginx = {
    enable = true;

    # OmniRoute entry point (via wireguard -> 2701). Formerly proxied to the
    # vllm-switcher on 8011; now goes straight to the native engine's
    # OpenAI/Anthropic server on 8010 (served name qwen3.8-27b-nvfp4).
    virtualHosts."vllm-api" = {
      listen = [{ addr = "0.0.0.0"; port = 2701; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:8010";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 900s;
          proxy_send_timeout 900s;
        '';
      };
    };

    # Metrics proxy – mirrors ollama-service port 9091. The engine's server.py
    # exposes GET /metrics on 8010, same as the vLLM coder did.
    virtualHosts."vllm-metrics" = {
      listen = [{ addr = "0.0.0.0"; port = 9091; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:8010/metrics";
      };
    };
  };
}
