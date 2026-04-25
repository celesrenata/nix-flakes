# Hardware configuration for esnixi
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ TWO-POOL BTRFS LAYOUT (2× NVMe, identically partitioned)                    │
# │                                                                              │
# │ /dev/nvme0n1                          /dev/nvme1n1                           │
# │   p1: ESP0       2G   vfat             p1: ESP1       2G   vfat (spare)     │
# │   p2: SWAP0     32G   swap             p2: SWAP1     32G   swap             │
# │   p3: SYSTEM0    2T   btrfs            p3: SYSTEM1    2T   btrfs            │
# │   p4: FAST0    rest   btrfs            p4: FAST1    rest   btrfs            │
# │                                                                              │
# │ esnixi-system (p3+p3)  data=raid1  meta=raid1  — mirrored, safe             │
# │   @root     → /              compress=zstd:3 noatime space_cache=v2 ssd     │
# │   @home     → /home          compress=zstd:3 noatime space_cache=v2 ssd     │
# │   @nix      → /nix           compress=zstd:3 noatime space_cache=v2 ssd     │
# │   @persist  → /persist       compress=zstd:3 noatime space_cache=v2 ssd     │
# │                                                                              │
# │ esnixi-fast (p4+p4)  data=raid0  meta=raid1  — striped, fast                │
# │   @var-lib-docker  → /var/lib/docker   compress=zstd:1 noatime ssd          │
# │   @var-lib-ollama  → /var/lib/ollama   compress=zstd:1 noatime ssd          │
# │   @var-lib-vllm    → /var/lib/vllm     compress=zstd:1 noatime ssd          │
# │   @var-tmp         → /var/tmp          compress=zstd:1 noatime ssd          │
# │   @fast            → /mnt/fast         compress=zstd:1 noatime ssd          │
# │   @games           → /mnt/games        compress=zstd:1 noatime ssd          │
# │                                                                              │
# │ Swap: SWAP0 + SWAP1 at priority 100 (kernel stripes natively)                │
# │                                                                              │
# │ UUIDs are predetermined (set via mkfs.btrfs -U in rebuild-storage-layout.sh) │
# │ Swap/ESP use partlabels — no UUID needed.                                    │
# │                                                                              │
# │ NOTE: nixos-generate-config only detects fsType and UUID.                    │
# │       All mount options below are set manually — do not regenerate.          │
# └──────────────────────────────────────────────────────────────────────────────┘

{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # ── Kernel / initrd ──────────────────────────────────────────────────
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "uas" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Native Btrfs multi-device, not mdadm.
  boot.swraid.enable = false;

  # ── System Pool (esnixi-system, raid1/raid1) ─────────────────────────
  # Predetermined UUID set by: mkfs.btrfs -U <uuid>
  # Options: zstd:3 (high ratio for nix store + source), noatime, space_cache=v2

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-1111-2222-3333-444455556666";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-1111-2222-3333-444455556666";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-1111-2222-3333-444455556666";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/persist" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-1111-2222-3333-444455556666";
    fsType = "btrfs";
    options = [ "subvol=@persist" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  # ── ESP ──────────────────────────────────────────────────────────────
  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/ESP0";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # ── Fast Pool (esnixi-fast, raid0/raid1) ─────────────────────────────
  # Predetermined UUID set by: mkfs.btrfs -U <uuid>
  # Options: zstd:1 (fast compression for throughput), noatime, space_cache=v2

  fileSystems."/var/lib/docker" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-7777-8888-9999-aaabbbcccddd";
    fsType = "btrfs";
    options = [ "subvol=@var-lib-docker" "compress=zstd:1" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/var/lib/ollama" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-7777-8888-9999-aaabbbcccddd";
    fsType = "btrfs";
    options = [ "subvol=@var-lib-ollama" "compress=zstd:1" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/var/lib/vllm" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-7777-8888-9999-aaabbbcccddd";
    fsType = "btrfs";
    options = [ "subvol=@var-lib-vllm" "compress=zstd:1" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/var/tmp" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-7777-8888-9999-aaabbbcccddd";
    fsType = "btrfs";
    options = [ "subvol=@var-tmp" "compress=zstd:1" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/mnt/fast" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-7777-8888-9999-aaabbbcccddd";
    fsType = "btrfs";
    options = [ "subvol=@fast" "compress=zstd:1" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/mnt/games" = {
    device = "/dev/disk/by-uuid/a1b2c3d4-7777-8888-9999-aaabbbcccddd";
    fsType = "btrfs";
    options = [ "subvol=@games" "compress=zstd:1" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  # ── Swap ─────────────────────────────────────────────────────────────
  swapDevices = [
    { device = "/dev/disk/by-partlabel/SWAP0"; priority = 100; }
    { device = "/dev/disk/by-partlabel/SWAP1"; priority = 100; }
  ];

  # ── Nix build directory ──────────────────────────────────────────────
  nix.settings.build-dir = "/mnt/fast/nix-build";
  systemd.tmpfiles.rules = [
    "d /mnt/fast 0755 celes users -"
    "d /mnt/fast/nix-build 0755 root root -"
  ];

  # ── Platform ─────────────────────────────────────────────────────────
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
