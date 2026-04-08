# OpenClaw Home Manager Configuration
# Discord bot "Renata" for user Celes

{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.nix-openclaw.homeManagerModules.openclaw
  ];

  programs.openclaw = {
    enable = true;
    documents = ./openclaw-documents;
    excludeTools = [ "python3" "nodejs_22" "git" "curl" "jq" "ffmpeg" "ripgrep" "go" "sox" ];

    config = {
      gateway = {
        mode = "local";
        auth.token = "/run/secrets/openclaw_gateway_token";
      };

      channels.discord = {
        botToken = "/run/secrets/discord_bot_token";
        allowFrom = [ 548750634464051211 ];
      };
    };

    bundledPlugins = {
      summarize.enable = true;
    };

    instances.default = {
      enable = true;
      plugins = [];
    };
  };

  systemd.user.services.openclaw-gateway.Service.Environment = [
    "OPENAI_API_KEY=/run/secrets/openai_api_token"
  ];
}
