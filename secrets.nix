# SOPS-nix Secrets Management Configuration
# Based on official documentation: https://github.com/Mic92/sops-nix
# This module configures encrypted secrets management using SOPS with SSH host keys.
#
# NOTE: Currently disabled due to symlink conflict issue
# The system works perfectly without this - it's only needed for the certificate

{ config, lib, pkgs, ... }:

{
  # SOPS configuration temporarily disabled to avoid symlink conflicts
  # The core system works perfectly without this
  # TODO: Fix the "cannot rename ... file exists" error
  
  # sops = {
  #   defaultSopsFile = ./secrets/secrets.yaml;
  #   validateSopsFiles = false;
  #   age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  #   secrets = {
  #     "home_certificate" = {
  #       path = "/run/secrets/home.crt";
  #       owner = "root";
  #       group = "root";
  #       mode = "0400";
  #     };
  #   };
  # };
}
