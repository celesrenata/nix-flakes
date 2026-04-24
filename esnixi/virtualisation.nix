{ config, lib, pkgs, pkgs-old, ... }:
{
  config = lib.mkIf config.my.profiles.virtualization.enable {
    # Enable Docker with bridge networking support
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      storageDriver = "btrfs";
      daemon.settings.data-root = config.my.paths.dockerData;
      package = pkgs-old.docker;
    };

    # Enable QEMU/KVM with bridge networking support
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;  # TPM emulation for Windows 11

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
            "${config.my.paths.dockerData}/windows/data:/storage"
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
