{ config, lib, pkgs, inputs, ... }:

{
  # Enable Hyte Touch Display system service
  services.hyte-touch.enable = false;

  # Enable autologin for celes during testing
  services.displayManager.autoLogin = {
    enable = true;
    user = "celes";
  };

  # Enable seatd for seat management
  services.seatd = {
    enable = true;
    user = "celes";
    group = "seat";
  };

  # Create seat group and add users
  users.groups.seat = {};
  users.users.celes.extraGroups = [ "seat" ];

  # Required packages for touch interface
  environment.systemPackages = with pkgs; [
    weston
    gamescope
    inputs.hyte-touch-infinite-flakes.packages.${pkgs.system}.touch-widgets
  ];
}
