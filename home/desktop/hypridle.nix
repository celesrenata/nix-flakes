# Hypridle Configuration
# Manages idle behavior including screen dimming, locking, and power management
# Part of the Hyprland desktop environment suite

{ config, lib, pkgs, ... }:

{
  # Enable hypridle service for idle management
  services.hypridle = {
    enable = true;
    
    settings = {
      # Command definitions for reuse
      "$lock_cmd" = "pidof hyprlock || hyprlock";
      "$suspend_cmd" = "pidof steam || systemctl suspend || loginctl suspend"; # fuck nvidia
      
      general = {
        lock_cmd = "$lock_cmd";
        before_sleep_cmd = "loginctl lock-session";
      };
      
      # Brightness dimming after 5 minutes
      listener = [
        {
          timeout = 300; # 5mins
          on-timeout = "brightnessctl | grep \"Current\" | awk '{ print $3 }' > ~/.cache/idle-brightness && brightnessctl set 10%";
          on-resume = "brightnessctl set $(cat ~/.cache/idle-brightness)";
        }
        
        # Screen lock after 7 minutes
        {
          timeout = 420; # 7mins
          on-timeout = "$lock_cmd";
        }
        
        # Display power off after 10 minutes
        {
          timeout = 600; # 10mins
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        
        # Suspend after 9 minutes (commented out)
        # {
        #   timeout = 540; # 9mins
        #   on-timeout = "$suspend_cmd";
        # }
      ];
    };
  };
  
  # Ensure required packages are available
  home.packages = with pkgs; [
    hypridle    # Idle daemon for Hyprland
    hyprlock    # Screen locker for Hyprland
    brightnessctl # Brightness control utility
  ];
}
