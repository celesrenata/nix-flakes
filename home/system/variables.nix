# Environment variables and session configuration
{ inputs, lib, pkgs, pkgs-unstable, ... }:

{
  # Session variables
  home.sessionVariables = {
    LD_LIBRARY_PATH = pkgs.lib.mkDefault "/run/opengl-driver/lib";
    OLLAMA_HOST = "http://10.1.1.12:2701";
  };
}
