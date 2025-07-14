{ pkgs, pkgs-unstable, ... }:
{
  config = {
    hardware.xpadneo.enable = true;
    #services.monado = {
    #  enable = true;
    #  defaultRuntime = true;
    #};
    #systemd.user.services.monado.environment = {
    #  STEAMVR_LH_ENABLE = "1";
    #  XRT_COMPOSITOR_COMPUTE = "1";
    #  #WMR_HANDTRACKING = "0";
    #};
    #programs.git = {
    #  enable = true;
    #  lfs.enable = true;
    #};
    programs.alvr = {
      enable = true;
    };
    services.protontweaks.enable = true;
  };
}
