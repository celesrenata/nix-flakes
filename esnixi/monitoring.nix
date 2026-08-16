{ config, lib, pkgs, options, ... }:

let
  # Create an ldconfig wrapper that generates/reads a cache in /var/cache
  # DCGM exporter calls `/sbin/ldconfig -p` internally and treats failure as fatal.
  ldconfigWrapper = pkgs.writeShellScript "ldconfig-wrapper" ''
    CACHE="/var/cache/ldconfig/ld.so.cache"
    CONF="/var/cache/ldconfig/ld.so.conf"
    mkdir -p /var/cache/ldconfig
    chmod 755 /var/cache/ldconfig

    # If called with -p (print), use our pre-built cache
    if [[ "$*" == *"-p"* ]]; then
      exec ${pkgs.glibc.bin}/bin/ldconfig -C "$CACHE" "$@"
    fi

    # Otherwise generate the cache
    cat > "$CONF" <<LDCONF
    /run/opengl-driver/lib
    ${pkgs.dcgm}/lib
    LDCONF
    exec ${pkgs.glibc.bin}/bin/ldconfig -f "$CONF" -C "$CACHE" "$@"
  '';
in
{
  systemd.services.dcgm-exporter = {
    description = "DCGM Exporter - NVIDIA GPU metrics for Prometheus";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 10;
      # Generate ldconfig cache before starting
      ExecStartPre = "${ldconfigWrapper}";
      ExecStart = "${pkgs.prometheus-dcgm-exporter}/bin/dcgm-exporter -a :9400";
    };
  };

  # DCGM default counters config (metrics to export)
  environment.etc."dcgm-exporter/default-counters.csv".source =
    "${pkgs.prometheus-dcgm-exporter.src}/etc/default-counters.csv";

  # Replace /sbin/ldconfig with our wrapper so dcgm-exporter's internal call works
  system.activationScripts.dcgm-ldconfig = ''
    mkdir -p /sbin
    ln -sf ${ldconfigWrapper} /sbin/ldconfig
  '';

  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" ];
    extraFlags = [ "--collector.ethtool" "--collector.softirqs" "--collector.tcpstat" ];
  };

  networking.firewall.allowedTCPPorts = [ 9100 9400 ];
}
