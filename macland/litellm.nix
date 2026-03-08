{ pkgs, lib, config, ... }:

let
  litellm-with-proxy = pkgs.python3Packages.litellm.overridePythonAttrs (old: {
    propagatedBuildInputs = (old.propagatedBuildInputs or []) ++ (with pkgs.python3Packages; [
      # Core proxy dependencies
      fastapi
      fastapi-sso
      starlette
      backoff
      pyyaml
      uvicorn
      gunicorn
      uvloop
      redis
      prisma
      pynacl
      orjson
      apscheduler
      pyjwt
      python-multipart
      cryptography
      
      # OpenTelemetry
      opentelemetry-api
      opentelemetry-sdk
      opentelemetry-exporter-otlp
      
      # Monitoring
      sentry-sdk
      prometheus-client
      
      # Cloud providers
      boto3
      aioboto3
      anthropic
      
      # Async
      async-generator
      aiohttp
      httpx
      anyio
      
      # Utils
      tenacity
      click
      rich
      jinja2
      python-dotenv
      tiktoken
      tokenizers
    ]);
  });
in
{
  # LiteLLM proxy service for routing LM Studio requests to multiple Ollama servers
  systemd.services.litellm = {
    description = "LiteLLM Proxy Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = "litellm";
      Group = "litellm";
      Restart = "on-failure";
      RestartSec = "5s";
      
      ExecStart = "${litellm-with-proxy}/bin/litellm --config /etc/litellm/config.yaml --port 4000";
      
      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  # Create litellm user
  users.users.litellm = {
    isSystemUser = true;
    group = "litellm";
    description = "LiteLLM service user";
  };
  
  users.groups.litellm = {};

  # LiteLLM configuration file
  environment.etc."litellm/config.yaml".text = ''
    model_list:
      # 4070 Ti Super (16GB VRAM) - http://10.1.1.12:2701
      - model_name: qwen3.5-32b
        litellm_params:
          model: ollama/qwen3.5:32b-q4_K_M
          api_base: http://10.1.1.12:2701
          
      - model_name: deepseek-4.1-28b
        litellm_params:
          model: ollama/deepseek-4.1:28b-q4_K
          api_base: http://10.1.1.12:2701
          
      - model_name: llama4-30b
        litellm_params:
          model: ollama/llama4.0:30b-q4_K
          api_base: http://10.1.1.12:2701
          
      - model_name: visionary-16b
        litellm_params:
          model: ollama/visionary-2.0:16b-q4_K
          api_base: http://10.1.1.12:2701

      # RTX 5090 (32GB VRAM) - http://192.168.42.254:11434
      - model_name: qwen3.5-64b
        litellm_params:
          model: ollama/qwen3.5:64b-q5_K_M
          api_base: http://192.168.42.254:11434
          
      - model_name: deepseek-4.1-60b
        litellm_params:
          model: ollama/deepseek-4.1:60b-q5_K
          api_base: http://192.168.42.254:11434
          
      - model_name: llama4-65b
        litellm_params:
          model: ollama/llama4.0:65b-q5_K
          api_base: http://192.168.42.254:11434
          
      - model_name: visionary-32b
        litellm_params:
          model: ollama/visionary-2.0:32b-q5_K
          api_base: http://192.168.42.254:11434

    router_settings:
      routing_strategy: simple-shuffle
      num_retries: 2
      timeout: 600
      
    general_settings:
      master_key: "sk-1234"  # Change this to a secure key
  '';

  # Create database directory
  systemd.tmpfiles.rules = [
    "d /var/lib/litellm 0750 litellm litellm -"
  ];

  # Install litellm package
  environment.systemPackages = [
    litellm-with-proxy
  ];

  # Open firewall for LiteLLM
  networking.firewall.allowedTCPPorts = [ 4000 ];
}
