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
      "home_certificate" = {
        path = "/run/secrets/home.crt";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "github_token" = {
        path = "/run/secrets/github_token";
        owner = "root";
        group = "root";
        mode = "0400";
      };
      "openai_api_token" = {
        path = "/run/secrets/openai_api_token";
        owner = "celes";
        group = "users";
        mode = "0400";
      };
    };
  };
}
