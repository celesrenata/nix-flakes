# SOPS-nix Secrets Management Configuration
# Based on official documentation: https://github.com/Mic92/sops-nix
# This module configures encrypted secrets management using SOPS with SSH host keys.
#
# NOTE: Currently disabled due to symlink conflict issue
# The system works perfectly without this - it's only needed for the certificate

{ config, lib, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    validateSopsFiles = false;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      github_token = {
        mode = "0440";
        group = "wheel";
      };
      openai_api_token = {
        mode = "0440";
        group = "wheel";
      };
    };
  };
}
