{ config, pkgs, ... }:

{
  systemd.services.dcgm-exporter = {
    description = "NVIDIA DCGM Exporter";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.dcgm-exporter}/bin/dcgm-exporter -a 0.0.0.0:9400";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  networking.firewall.allowedTCPPorts = [ 9400 ];
}
