{ config, lib, pkgs, inputs, ... }:

{
  # Sops secret for Grafana API token
  sops.secrets.grafana_api_token = {
    sopsFile = ../secrets/secrets.yaml;
    owner = "celes";
    group = "users";
    mode = "0400";
  };

  # Enable Hyte Touch Display isolated Cage session
  services.hyte-touch.enable = true;
  
  # Enable seatd for multi-session support
  services.seatd = {
    enable = true;
    user = "celes";
    group = "seat";
  };
  
  # Add celes to seat group
  users.groups.seat = {};
  users.users.celes.extraGroups = [ "seat" ];

  # Enable autologin for celes during testing
  services.displayManager.autoLogin = {
    enable = true;
    user = "celes";
  };

  # Required packages for touch interface
  environment.systemPackages = with pkgs; [
    cage
    inputs.hyte-touch-infinite-flakes.packages.${pkgs.system}.start-hyte-touch
  ];
}
