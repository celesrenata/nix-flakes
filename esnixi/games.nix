{ pkgs, pkgs-unstable, pkgs-old, ... }:
{
  config = {
    # Steam requirements
    boot.kernel.sysctl."vm.legacy_va_layout" = 0;
    security.pam.loginLimits = [
      {
        domain = "*";
        type = "soft";
        item = "stack";
        value = "8192";
      }
    ];
    
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
    programs.gamemode.enable = true;
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;
      extraPackages = with pkgs; [
        bumblebee
        primus
        mesa-demos
        #steamcmd
        #steam-tui
        qt6.qtwayland
        nss
        protontricks
        xorg.libxkbfile
        kdePackages.qtwayland
        libsForQt5.qt5.qtwayland
      ];
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
    programs.alvr = {
      enable = true;
      package = pkgs.alvr; 
    };
    # services.protontweaks.enable = true;
  };
}
