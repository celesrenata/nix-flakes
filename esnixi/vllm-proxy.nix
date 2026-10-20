{ ... }:

{
  imports = [ ./vllm.nix ./comfy-worker.nix ./vllm-idle.nix ./qwen3-engine.nix ];

  # The mkyt native engine is the sole 5090 coder (replaced vLLM). The
  # vllm-switcher was retired (Option 2b), so OmniRoute reaches the coder
  # directly on 8010 rather than through the switcher's 8011 front door.
  my.engines.qwen3Native.enable = true;
  # Concurrency 4: the engine batches decode/verify across requests (its GEMMs
  # handle up to 64 rows = 8 reqs x 8 spec tokens, so 4 is well inside the
  # envelope). MAX_TOKENS_FIT=1 sizes the KV pool to what the 4-seq state leaves.
  my.engines.qwen3Native.maxSeqs = 4;

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
