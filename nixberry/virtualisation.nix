{ ... }:
{
  config = {
    # Enable VMWare Tools.
    virtualisation.docker = {
      enable = true;
      #enableOnBoot = true;
      storageDriver = "btrfs";
      daemon.settings.data-root = "/mnt/docker";
    };
#    virtualisation.oci-containers = {
#      backend = "docker";
#      containers = {
#        windows-arm = {
#          hostname = "winvm";
#          #autoStart = true;
#          image = "dockurr/windows-arm";
#          volumes = [
#            "/mnt/shared:/shared"
#          ];:
#          ports = [
#            "8006:8006"
#            "3389:3389"
#          ];
#          environment = {
#            VERSION = "win11";
#            USERNAME = "celes";
#            PASSWORD = "renata";
#          };
#          extraOptions = [
#            "--cap-add=NET_ADMIN"
#            "--device=/dev/kvm"
#          ];
#        };
#      };
#    };
    # Enable QEMU.
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
  };
}
