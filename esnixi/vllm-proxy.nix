{ ... }:

{
  services.nginx = {
    enable = true;

    # API proxy – mirrors ollama-service port 2701
    virtualHosts."vllm-api" = {
      listen = [{ addr = "0.0.0.0"; port = 2701; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        proxyWebsockets = true;
      };
    };

    # Metrics proxy – mirrors ollama-service port 9091
    virtualHosts."vllm-metrics" = {
      listen = [{ addr = "0.0.0.0"; port = 9091; }];
      locations."/" = {
        proxyPass = "http://127.0.0.1:8000/metrics";
      };
    };
  };
}
