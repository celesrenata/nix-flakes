{ lib, pkgs, ... }:

{
  networking.wireguard.interfaces.omniroute = {
    ips = [ "192.168.133.3/28" ];
    privateKeyFile = "/var/lib/wireguard/omniroute-5090.key";

    peers = [
      {
        publicKey = "KSDOUGxoPHWuFvGffDdLggDaTHbm/zBbO3sxi7AcWjA=";
        endpoint = "frameshift.net:51827";
        allowedIPs = [
          "192.168.133.0/28"
          "10.1.1.0/24"
          "10.42.0.0/16"
        ];
        persistentKeepalive = 25;
      }
    ];
  };

  # This host deliberately does not block boot on network-online. Retry the
  # generated peer unit when DNS is not ready during early activation.
  systemd.services."wireguard-omniroute-peer-KSDOUGxoPHWuFvGffDdLggDaTHbm-zBbO3sxi7AcWjA\\x3d".serviceConfig = {
    Restart = "on-failure";
    RestartSec = "15s";
  };

  # Keep Ollama private to the host and publish it only on the WireGuard IP.
  services.ollama.host = lib.mkForce "127.0.0.1";
  services.nginx.virtualHosts."vllm-api".listen = lib.mkForce [
    { addr = "127.0.0.1"; port = 2701; }
  ];
  systemd.services.omniroute-ollama-proxy = {
    description = "Expose Ollama only through the OmniRoute WireGuard tunnel";
    after = [ "wireguard-omniroute.service" "ollama.service" ];
    wants = [ "wireguard-omniroute.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:11434,bind=192.168.133.3,reuseaddr,fork TCP:127.0.0.1:11434";
      Restart = "always";
      RestartSec = "10s";
    };
  };

  systemd.services.omniroute-vllm-proxy = {
    description = "Expose the authenticated vLLM switcher only through WireGuard";
    after = [ "wireguard-omniroute.service" "nginx.service" ];
    wants = [ "wireguard-omniroute.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:2701,bind=192.168.133.3,reuseaddr,fork TCP:127.0.0.1:2701";
      Restart = "always";
      RestartSec = "10s";
    };
  };
}
