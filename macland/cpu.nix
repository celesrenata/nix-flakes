{ pkgs, ... }:
{
  config = {
    # Power and Thermal.
    services.thermald.enable = true;
    #services.tlp.enable = true;
    services.auto-cpufreq.enable = true;
    services.auto-cpufreq.settings = {
      battery = {
        governor = "onDemand";
        turbo = "auto";
      };
      charger = {
        governor = "onDemand";
        turbo = "auto";
      };
    };
    systemd.services.t2fanrd = {
      enable = true;
      description = "T2 Mac Fan Controller";
      unitConfig = {
        Type = "simple";
      };
      serviceConfig = {
        ExecStart = "${pkgs.t2fanrd}/bin/t2fanrd";
      };
      wantedBy = [ "multi-user.target"];
    };
    systemd.services.t2suspendfix = {
      enable = true;
      description = "modules to be unloaded and reloaded for suspend";
      unitConfig = {
        StopWhenUnneeded = "yes";
      };
      before = [ "sleep.target" ];
      serviceConfig = {
        User = "root";
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = [
          "${pkgs.kmod}/bin/modprobe -r brcmfmac_wcc"
          "${pkgs.kmod}/bin/modprobe -r brcmfmac"
          "${pkgs.kmod}/bin/rmmod -f apple-bce"
        ];
        ExecStop = [
          "${pkgs.kmod}/bin/modprobe apple-bce"
          "${pkgs.kmod}/bin/modprobe brcmfmac"
          "${pkgs.kmod}/bin/modprobe brcmfmac_wcc"
        ];
      };
      wantedBy = [ "sleep.target" ];
    };
    systemd.sleep.extraConfig = ''
      HibernateDelaySec=1h # very low value to test suspend-then-hibernate
      SuspendState=mem # suspend2idle is buggy :(
    '';
  };
}
