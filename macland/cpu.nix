{ ... }:
{
  config = {
    # Power and Thermal.
    services.thermald.enable = true;
    services.tlp.enable = true;
    services.auto-cpufreq.enable = true;
    services.auto-cpufreq.settings = {
      battery = {
        governor = "balanced";
        turbo = "never";
      };
      charger = {
        governor = "performance";
        turbo = "auto";
      };
    };
  };
}