# Environment variables and session configuration
{ inputs, lib, pkgs, ... }:

{
  # Session variables
  home.sessionVariables = {
    OLLAMA_HOST = "http://10.1.1.12:2701";
  };
}
