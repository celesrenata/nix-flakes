# Environment variables and session configuration
{ inputs, lib, pkgs, ... }:

{
  # Session variables
  home.sessionVariables = {
    OLLAMA_HOST = "http://10.1.1.12:2701";
    npm_config_prefix = "/home/celes/.npm-global";
  };

  # Ensure npm global prefix dir exists for npx MCP servers on NixOS
  home.file.".npm-global/lib/.keep".text = "";
}
