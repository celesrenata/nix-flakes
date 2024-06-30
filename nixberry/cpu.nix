{ ... }:
{
  config = {
    # Power and Thermal.
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
  };
}
