{ ... }:

{
  imports = [ ./vllm.nix ./comfy-worker.nix ./vllm-idle.nix ];

  services.nginx = {
    enable = true;

    # Authenticated model-switching API; vLLM itself remains loopback-only.
    virtualHosts."vllm-api" = {
      listen = [{ addr = "0.0.0.0"; port = 2701; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:8011";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_read_timeout 900s;
          proxy_send_timeout 900s;
        '';
      };
    };

    # Metrics proxy – mirrors ollama-service port 9091
    virtualHosts."vllm-metrics" = {
      listen = [{ addr = "0.0.0.0"; port = 9091; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:8010/metrics";
      };
    };
  };
}
