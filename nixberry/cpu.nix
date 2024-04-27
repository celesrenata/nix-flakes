{ ... }:
{
  config = {
    # Power and Thermal.
    services.auto-cpufreq.enable = true;
    services.auto-cpufreq.settings = {
      battery = {
        governor = "balanced";
        turbo = "auto";
      };
      charger = {
        governor = "balanced";
        turbo = "auto";
      };
    };
  };
}
