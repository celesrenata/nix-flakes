{ config, pkgs, ... }:

{
  sops.secrets.huggingface_token = {
    sopsFile = ../secrets/secrets.yaml;
    owner = "vllm";
    group = "vllm";
  };

  systemd.services.vllm = {
    description = "vLLM OpenAI-compatible API server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "vllm";
      Group = "vllm";
      ExecStart = "${pkgs.vllm}/bin/vllm serve Qwen/Qwen2.5-7B-Instruct --host 0.0.0.0 --port 8000 --gpu-memory-utilization 0.7";
      Restart = "on-failure";
      RestartSec = "10s";
      Environment = [
        "HOME=/var/lib/vllm"
        "HF_TOKEN_PATH=${config.sops.secrets.huggingface_token.path}"
      ];
    };
  };

  users.users.vllm = {
    isSystemUser = true;
    group = "vllm";
    home = "/var/lib/vllm";
    createHome = true;
  };

  users.groups.vllm = {};
}
