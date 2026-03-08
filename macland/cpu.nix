{ pkgs, ... }:
{
  config = {
    # Power and Thermal.
    services.thermald.enable = true;
    services.upower.enable = true;
 
    # Let TLP manage CPU frequency scaling
    powerManagement = {
      enable = true;
    };
    
    # Intel P-State driver configuration
    boot.kernelParams = [
      "intel_pstate=active"
    ];
    
    # TLP for advanced power management
    services.tlp = {
      enable = true;
      settings = {
        # AC: responsive performance; BAT: conservative
        CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        
        # AC: allow near-full performance; BAT: conservative
        CPU_MAX_PERF_ON_AC = 90;
        CPU_MAX_PERF_ON_BAT = 55;
        
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
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
