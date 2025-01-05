{ config, lib, pkgs, options, ... }:

{
  #systemd.services = {
  #  # DCGM Exporter for NVIDIA GPUS
  #  dcgm-exporter = {
  #    enable = true;
  #    description = "prometheus node exporter for Nvidia";
  #    serviceConfig = {
  #      User = "root";
  #      Type = "simple";
  #      Restart = "always";
  #      ExecStart = [
  #        "${pkgs.bash}/bin/bash ${pkgs.prometheus-dcgm-exporter}/bin/dcgm-exporter --web.listen-address 0.0.0.0:9400 --web.telemetry-path '/metrics'"
  #      ];
  #      ExecStop = [
  #        "${pkgs.bash}/bin/bash ${pkgs.prometheus-dcgm-exporter}/bin/dcgm-exporter"
  #      ];
  #    };
  #    wantedBy = [ "multi-user.target" ];
  #  };
  #};

  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" ];
    extraFlags = [ "--collector.ethtool" "--collector.softirqs" "--collector.tcpstat" ];
  };
}

