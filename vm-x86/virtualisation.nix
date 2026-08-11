# Virtualisation / Guest services for nixbox (VirtualBox/VMware x86_64 VM)
# Guest additions are enabled via hardware-configuration.nix.
# This file handles Docker (for ToolHive MCP) and shared folder access.

{ config, lib, pkgs, ... }:

{
  config = {
    # Docker for ToolHive MCP server containers
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };

    # VirtualBox shared folders support (vboxsf)
    # VMware shared folders use open-vm-tools (vmhgfs-fuse)
    environment.systemPackages = with pkgs; [
      open-vm-tools  # VMware shared folders + clipboard
    ];
  };
}
