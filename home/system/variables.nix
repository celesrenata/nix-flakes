# Environment variables and session configuration
{ inputs, lib, pkgs, ... }:

{
  # Session variables
  home.sessionVariables = {
    # On aarch64 VM: point to Mac host running Ollama (Parallels gateway)
    # On x86_64 desktop: point to local network inference server
    OLLAMA_HOST = if pkgs.stdenv.hostPlatform.isAarch64
      then "http://10.211.55.2:11434"
      else "http://10.1.1.12:2701";
    npm_config_prefix = "/home/celes/.npm-global";
  };

  # Ensure npm global prefix dir exists for npx MCP servers on NixOS
  home.file.".npm-global/lib/.keep".text = "";
}
