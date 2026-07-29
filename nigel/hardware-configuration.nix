# Hardware configuration for Nigel (Lenovo ideacentre AIO 700-27ISH)
# CPU: Intel i7-6700 (8) @ 4.000GHz (Skylake)
# GPU: NVIDIA GeForce GTX 950M (Hyprland)
# GPU: Intel HD Graphics 530 (Windows VM passthrough)
# Memory: 15895MiB total

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ── Kernel / initrd ──────────────────────────────────────────────────
  boot.initrd.availableKernelModules = [ "ehci_pci" "xhci_pci" "usbhid" "sr_mod" ];
  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" "i915" ];
  boot.kernelModules = [ "uinput" "nvidia" "i915" "kvm-intel" "kvm" "vfio-pci" "vfio" "vfio_iommu" "v4l2loopback" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];

  # ── IOMMU for GPU passthrough ────────────────────────────────────────
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    # Reserve Intel GPU for VM passthrough
    # "pci=realloc=off"
  ];

  # ── Btrfs subvolume layout ───────────────────────────────────────────
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-ROOT-UUID";
    fsType = "btrfs";
    options = [ "subvol=root" "compress=zstd" "noatime" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-ROOT-UUID";
    fsType = "btrfs";
    options = [ "subvol=home" "compress=zstd" "noatime" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-ROOT-UUID";
    fsType = "btrfs";
    options = [ "subvol=nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-ESP-UUID";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # ── Swap ─────────────────────────────────────────────────────────────
  swapDevices = [
    { device = "/dev/disk/by-uuid/CHANGE-ME-SWAP-UUID"; }
  ];

  # ── Platform ─────────────────────────────────────────────────────────
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
