{ ... }:
{
  config = {
    # Power and Thermal.
    services.thermald.enable = true;
    #services.tlp.enable = true;
    services.auto-cpufreq.enable = true;
    services.auto-cpufreq.settings = {
      battery = {
        governor = "performance";
        turbo = "auto";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
    programs.coolercontrol = {
      enable = true;
    };
    #virtualisation.virtualbox.host.enable = true;
    #virtualisation.virtualbox.host.enableExtensionPack = true;
    virtualisation.docker.enable = true;
    users.extraGroups.vboxusers.members = [ "celes" ];
  };
}
