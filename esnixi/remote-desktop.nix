# Remote Desktop Configuration for ESXi Baremetal System
# Provides remote access capabilities via various protocols

{ config, lib, pkgs, ... }:

let
  # RDP (Remote Desktop Protocol) - Windows-style remote desktop client
  freerdp = pkgs.freerdp;
in

{
  config = {
    # FreeRDP client for connecting to Windows/Remote Desktop servers
    environment.systemPackages = with pkgs; [
      freerdp
    ];
    
    # SSH - already enabled globally via services.openssh.enable = true
    
  };
  
}
