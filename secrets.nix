# SOPS-nix Secrets Management Configuration
# Based on official documentation: https://github.com/Mic92/sops-nix
# This module configures encrypted secrets management using SOPS with SSH host keys.

{ config, lib, pkgs, ... }:

{
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    validateSopsFiles = false;
    secrets = {
      github_token = {
        mode = "0440";
        group = "wheel";
      };
      input-leap-stabulous-fingerprint = {
        mode = "0400";
        owner = "celes";
        group = "users";
      };
      openai_api_key = {
        mode = "0440";
        group = "wheel";
      };
      grafana_service_account_token = {
        mode = "0440";
        group = "wheel";
      };
    };
  };
}
