# Virtualisation configuration for Nigel (Ryzen AM5 desktop)
# Docker + QEMU/KVM; AMD IOMMU available for optional GPU/device passthrough.
# Windows runs in a Docker container via dockurr/windows.

{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.my.profiles.virtualization.enable {
    # ── Docker (btrfs backend) ──────────────────────────────────────────
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      storageDriver = "btrfs";
      daemon.settings.data-root = config.my.paths.dockerData;
      package = pkgs.docker;
    };

    # ── QEMU/KVM ─────────────────────────────────────────────────────────
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

    # ── AMD virtualisation + VFIO for optional passthrough ──────────────
    boot.kernelModules = [ "kvm-amd" "kvm" "vfio-pci" "vfio" "vfio_iommu" ];

    boot.extraModprobeConfig = ''
      # Nested virtualisation on AMD (SVM).
      options kvm_amd nested=1
      # To pass a discrete GPU/device into a VM, bind it to vfio-pci here, e.g.:
      #   options vfio-pci ids=10de:xxxx,10de:yyyy
      # Find the IDs with: lspci -nn | grep -Ei "VGA|Audio"
    '';

    boot.kernelParams = [
      "amd_iommu=on"
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
