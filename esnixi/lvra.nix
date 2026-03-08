# VR Configuration for ESXi Baremetal System
# Provides WiVRn and ALVR support for Virtual Reality streaming

{ config, lib, pkgs, ... }:

let
  # WiVRn - Wireless VR streaming server
  wivrn = pkgs.wivrn;
  
  # ALVR - Alternative VR streaming solution
  alvr = pkgs.alvr;
in

{
  config = {
    # WiVRn service for wireless VR streaming (SteamVR)
    services.wivrn = lib.mkDefault {
      enable = true;
      openFirewall = true;
      package = wivrn;
      
      # Write information to /etc/xdg/openxr/1/active_runtime.json, 
      # VR applications will automatically read this and work with WiVRn
      defaultRuntime = true;
      
      # Run WiVRn as a systemd service on startup
      autoStart = true;
      
      # Configuration for WiVRn (https://github.com/WiVRn/WiVRn/blob/master/docs/configuration.md)
      config = {
        enable = true;
        
        json = {
          # Foveation scaling (1.0x is full quality)
          scale = 1.0;
          
          # Bitrate in bits per second (100 Mb/s recommended)
          bitrate = 100000000;
          
          # Encoder configuration
          encoders = [
            {
              encoder = "vaapi";      # Use Intel/AMD hardware encoding
              codec = "h265";         # HEVC for better quality at same bitrate
              
              # Scaling factors (1.0 x 1.0 is full resolution)
              width = 1.0;
              height = 1.0;
              offset_x = 0.0;
              offset_y = 0.0;
            }
          ];
        };
      };
    };
    
    # ALVR - Alternative VR streaming (Steam Link alternative)
    programs.alvr.enable = lib.mkDefault true;
    programs.alvr.package = alvr;
    
    # OpenXR runtime support for VR applications
    systemd.user.services.monado = lib.mkIf config.services.wivrn.enable {
      enable = true;
      
      description = "OpenXR Runtime Monitor";
      
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      
      wantedBy = [ "default.target" ];
      
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        
        Environment = [
          "STEAMVR_LH_ENABLE=1"           # Enable Link Home (hand tracking)
          "XRT_COMPOSITOR_COMPUTE=1"      # Use compute compositor
          "WMR_HANDTRACKING=0"            # Disable Windows Mixed Reality hand tracking
        ];
      };
    };
    
  };
  
}
