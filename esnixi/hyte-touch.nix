{ config, lib, pkgs, ... }:

{
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
    # Add the hyte-touch-widgets from our flake
    (callPackage /home/celes/sources/celesrenata/hyte-touch-infinite-flakes/packages/touch-widgets.nix {
      inherit (inputs) quickshell;
    })
  ];
}
