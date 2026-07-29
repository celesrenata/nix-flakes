# Virtualisation configuration for Nigel (Lenovo ideacentre AIO 700-27ISH)
# Intel HD Graphics 530 passed through to Windows VM via vfio-pci
# Windows runs in Docker container via dockurr/windows with Intel GPU acceleration

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.my.profiles.virtualization.enable {
    # ── Docker with Intel GPU passthrough support ────────────────────────
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      storageDriver = "btrfs";
      daemon.settings.data-root = config.my.paths.dockerData;
      package = pkgs.docker;
    };

    # ── QEMU/KVM for GPU passthrough ────────────────────────────────────
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = true;
        swtpm.enable = true;
      };
    };

    programs.virt-manager.enable = true;
    users.users.celes.extraGroups = [ "libvirtd" "kvm" ];

    # ── Intel GPU passthrough via vfio-pci ──────────────────────────────
    boot.kernelModules = [ "kvm-intel" "kvm" "vfio-pci" "vfio" "vfio_iommu" ];

    boot.extraModprobeConfig = ''
      # Bind Intel HD Graphics 530 to vfio-pci for VM passthrough
      # PCI ID for Skylake GT2 (HD Graphics 530) = 8086:1912
      # Verify with: lspci -nn | grep "VGA" | grep Intel
      options vfio-pci ids=8086:1912
      options kvm_intel nested=1
    '';

    boot.kernelParams = [
      "intel_iommu=on"
      "iommu=pt"
    ];

    # ── Windows VM via dockurr/windows with Intel GPU ───────────────────
    # mini-vm variant uses minimum RAM (4GB) and DISK_SIZE
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
            "${config.my.paths.dockerData}/windows/oem:/oem"
          ];
          ports = [
            "8006:8006"
            "3389:3389"
          ];
          environment = {
            VERSION = "win11l";  # Windows 11 LTSC — smaller footprint
            USERNAME = "celes";
            PASSWORD = "renata";
            DISK_SIZE = "32G";   # Minimum viable disk
            RAM_SIZE = "4G";     # Minimum viable RAM
            CPU_CORES = "4";
          };
          extraOptions = [
            "--cap-add=NET_ADMIN"
            "--device=/dev/kvm"
            "--device=/dev/vfio/vfio"
            "--stop-timeout=120"
          ];
        };
      };
    };

    # ── tmpfiles: ensure directories ────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d /mnt/shared 0755 celes users -"
      "d ${config.my.paths.dockerData}/windows/data 0755 - - -"
      "d ${config.my.paths.dockerData}/windows/oem 0755 - - -"
    ];

    # ── OEM scripts for Windows post-install ────────────────────────────
    system.activationScripts.winapps-oem = ''
      mkdir -p ${config.my.paths.dockerData}/windows/oem
      mkdir -p ${config.my.paths.dockerData}/windows/data
      chattr +C ${config.my.paths.dockerData}/windows/data 2>/dev/null || true
      cp -f ${../scripts/install.bat} ${config.my.paths.dockerData}/windows/oem/install.bat
    '';
  };
}
