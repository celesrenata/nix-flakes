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
      omniroute_zoo_api_key = {
        # Gateway admin API key for OmniRoute combo/alias management (hybrid/reader).
        # Readable by wheel so operator tooling and the combo-apply step can use it.
        mode = "0440";
        group = "wheel";
      };
      omniroute_management_api_key = {
        # Manage-scoped OmniRoute API key for combo/connection management (POST /api/combos).
        # Distinct from the usage-only zoo key; readable by wheel for operator tooling.
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
