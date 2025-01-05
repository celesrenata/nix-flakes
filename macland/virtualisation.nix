{ ... }:
{
  config = {
    # Enable VMWare Tools.
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      storageDriver = "btrfs";
      daemon.settings.data-root = "/home/docker";
    };
    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        windows = {
          hostname = "winvm";
          autoStart = true;
          image = "dockurr/windows";
          volumes = [
            "/mnt/shared:/shared"
            "/home/docker/windows/data:/storage"
            "/etc/nixos/scripts:/oem"
          ];
          ports = [
            "8006:8006"
            "3389:3389"
          ];
          environment = {
            VERSION = "win11p";
            USERNAME = "celes";
            PASSWORD = "renata";
            DISK_SIZE = "128G";
            RAM_SIZE = "8G";
            CPU_CORES = "4";
          };
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--device=/dev/kvm"
            "--stop-timeout=120"
          ];
        };
      };
    };
    # Enable QEMU.
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
  };
}
