# MCP (Model Context Protocol) Server Configuration
# Generates ~/.kiro/settings/mcp.json declaratively and wraps servers
# that need runtime secrets via sops-nix.
{ inputs, lib, pkgs, config, ... }:

let
  # ── Secret Paths ──────────────────────────────────────────────────────────
  openAISecretPath = "/run/secrets/openai_api_key";
  githubTokenPath = "/run/secrets/github_token";

  # ── Wrapped Servers (secrets injected at runtime) ─────────────────────────
  chatGpt52Wrapped = pkgs.writeShellApplication {
    name = "mcp-chat-gpt52";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export AI_CHAT_KEY="$(cat ${openAISecretPath})"
      export AI_CHAT_NAME="GPT-5.2"
      export AI_CHAT_MODEL="gpt-5.2"
      export AI_CHAT_BASE_URL="https://api.openai.com/v1"
      export AI_CHAT_TIMEOUT="300000"
      exec ${lib.getExe pkgs.any-chat-completions-mcp} "$@"
    '';
  };

  chatCodexWrapped = pkgs.writeShellApplication {
    name = "mcp-chat-codex";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export AI_CHAT_KEY="$(cat ${openAISecretPath})"
      export AI_CHAT_NAME="GPT-5.5"
      export AI_CHAT_MODEL="gpt-5.5"
      export AI_CHAT_BASE_URL="https://api.openai.com/v1"
      export AI_CHAT_TIMEOUT="300000"
      exec ${lib.getExe pkgs.any-chat-completions-mcp} "$@"
    '';
  };

  githubWrapped = pkgs.writeShellApplication {
    name = "mcp-server-github-wrapped";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${githubTokenPath})"
      exec ${lib.getExe pkgs.mcp-server-github} "$@"
    '';
  };

  # ── MCP Client Configuration ─────────────────────────────────────────────
  mcpConfig = {
    mcpServers = {
      sequential-thinking = {
        command = lib.getExe pkgs.mcp-server-sequential-thinking;
        args = [ ];
        env = { };
        autoApprove = [ "sequentialthinking" ];
      };

      memory = {
        command = lib.getExe pkgs.mcp-server-memory;
        args = [ ];
        env = { };
      };

      github = {
        command = lib.getExe githubWrapped;
        args = [ ];
        env = { };
        autoApprove = [ "get_file_contents" ];
      };

      chat-gpt52 = {
        command = lib.getExe chatGpt52Wrapped;
        args = [ ];
        env = { };
        autoApprove = [ "chat-with-gpt-5.2" ];
        timeout = 120000;
      };

      chat-codex = {
        command = lib.getExe chatCodexWrapped;
        args = [ ];
        env = { };
        autoApprove = [ "chat-with-gpt-5.5" ];
        timeout = 120000;
      };

      fetch = {
        command = "${pkgs.uv}/bin/uvx";
        args = [ "mcp-server-fetch" ];
        env = { };
      };
    };
  };

  # ── Kiro Agent Configuration ─────────────────────────────────────────────
  kiroDefaultAgent = {
    name = "kiro_default";
    description = "Default Kiro CLI agent with full MCP tool access";
    tools = [ "*" ];
    allowedTools = [ ];
    useLegacyMcpJson = true;
  };

in
{
  home.file.".kiro/settings/mcp.json" = {
    text = builtins.toJSON mcpConfig;
  };

  home.file.".kiro/agents/kiro_default.json" = {
    text = builtins.toJSON kiroDefaultAgent;
  };
}
