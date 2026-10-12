{ ... }:

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
}
