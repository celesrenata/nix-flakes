# Virtualisation / Guest services for nixberry (Parallels Desktop aarch64 VM)
# Parallels Tools are enabled via hardware.parallels.enable in hardware-configuration.nix
# This file handles Docker (for ToolHive MCP) and Parallels-specific tweaks.

{ config, lib, pkgs, ... }:

{
  config = {
    # Docker for ToolHive MCP server containers
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };

    # Parallels shared folders (mounted via prl_fs FUSE)
    # Access macOS shared folders at /media/psf/
    environment.systemPackages = with pkgs; [
      fuse  # FUSE support for prl_fs shared folders
    ];
  };
}
