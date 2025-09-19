{ pkgs, ... }:
{
  config = {
    # Enable VMWare Tools.
    # virtualisation.vmware.guest.enable = true;

    # Enable Docker with bridge networking support
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      storageDriver = "btrfs";
      daemon.settings.data-root = "/home/docker";
    };
    
    #virtualisation.vmware.host.enable = true;
    #virtualisation.vmware.host.package = pkgs.vmware-workstation.override { enableMacOSGuests = true; };

#    virtualisation.virtualbox.host.enable = true;
#    virtualisation.virtualbox.host.enableKvm = true;
#    virtualisation.virtualbox.host.enableExtensionPack = true;
#    users.extraGroups.vboxusers.members = [ "celes" ];

    # Enable QEMU/KVM with bridge networking support
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;  # TPM emulation for Windows 11
        ovmf = {
          enable = true;      # UEFI support
          packages = [ pkgs.OVMFFull.fd ];
        };
      };
    };

    # Enable virt-manager for GUI VM management
    programs.virt-manager.enable = true;

    # Add user to libvirt group for VM management
    users.users.celes.extraGroups = [ "libvirtd" "kvm" ];

    # Enable bridge networking for VMs
    virtualisation.libvirtd.qemu.verbatimConfig = ''
      # Allow VMs to use the br0 bridge for direct network access
      cgroup_device_acl = [
        "/dev/null", "/dev/full", "/dev/zero",
        "/dev/random", "/dev/urandom",
        "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
        "/dev/rtc","/dev/hpet", "/dev/vfio/vfio"
      ]
    '';

    # Container configuration with bridge networking
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
            VERSION = "win11";
            USERNAME = "celes";
            PASSWORD = "renata";
            DISK_SIZE = "128G";
            RAM_SIZE = "8G";
            CPU_CORES = "6";
          };
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--device=/dev/kvm"
            "--stop-timeout=120"
          ];
        };
      };
    };

    # Enable KVM kernel modules
    boot.kernelModules = [ "kvm-intel" "kvm-amd" ];
    
    # Enable nested virtualization for better VM performance
    boot.extraModprobeConfig = ''
      options kvm_intel nested=1
      options kvm_amd nested=1
    '';

    # Enable IOMMU for GPU passthrough (if needed)
    boot.kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
    ];
  };
}
