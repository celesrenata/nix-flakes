{ pkgs, ... }:
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
            ARGUMENTS = "-device usb-host,vendorid=0x264a,productid=0x233c";
          };
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--device=/dev/kvm"
            "--privileged"
            "--device-cgroup-rule=c 189:* rmw"
            "--device=/dev/bus/usb"
            "--stop-timeout=120"
          ];
        };
      };
    };
    
    # Enable QEMU and libvirt with bridge support
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;

      };
    };
    
    # Enable KVM
    virtualisation.kvmgt.enable = true;
    
    # Add required kernel modules for macvtap bridging
    boot.kernelModules = [ "kvm-intel" "kvm-amd" "macvtap" "vfio-pci" ];
    
    # Enable virt-manager
    programs.virt-manager.enable = true;
    
    # Add virtualization packages
    environment.systemPackages = with pkgs; [
      virt-viewer
      spice
      spice-gtk
      spice-protocol
      virtio-win
      bridge-utils
    ];
  };
}
