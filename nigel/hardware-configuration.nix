# Hardware configuration for Nigel (Ryzen AM5 desktop)
# CPU: AMD Ryzen (AM5 socket, Zen 4/5)
# GPU: modern NVIDIA (Turing+/Ada — open kernel module capable)
# Storage: NVMe, auto-tiered by nigel/setup.sh
#
# ┌──────────────────────────────────────────────────────────────────────────────┐
# │ AUTO-TIERED BTRFS LAYOUT (built by nigel/setup.sh)                           │
# │                                                                              │
# │ The setup script detects every fixed drive, classifies it                   │
# │ (NVMe > SATA SSD > spinning HDD), and places subvolumes by speed:            │
# │                                                                              │
# │   FASTEST non-spindle drive → btrfs label "nigel-system"                     │
# │     @root     → /          (hot OS)                                          │
# │     @nix      → /nix       (Nix store — ALWAYS on the fastest drive)         │
# │     @persist  → /persist                                                     │
# │     @build    → /var/tmp/nix-build  (build scratch — ALWAYS fastest)         │
# │                                                                              │
# │   @home → /home lives on btrfs label "nigel-home":                           │
# │     • a SECOND SSD/NVMe if one exists (frees the system drive), else         │
# │     • the SAME fast drive (single-SSD box).                                  │
# │     NEVER a spindle — "unless spindle!!!".                                    │
# │                                                                              │
# │   @bulk → /mnt/bulk + @games → /mnt/games on btrfs label "nigel-bulk":        │
# │     • the slowest drive (a spindle if present), else the home drive.         │
# │     Spindles ONLY ever hold cold bulk — never /nix, /, build, or /home.      │
# │                                                                              │
# │ The config references btrfs *labels* (by-label) and partition *labels*       │
# │ (by-partlabel), so it is independent of which physical nvmeXnY won the race. │
# │ All three btrfs labels always exist after setup.sh runs (on a single-drive  │
# │ box they can resolve to the same filesystem). ESP + swap use partlabels.     │
# └──────────────────────────────────────────────────────────────────────────────┘

{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # ── Kernel / initrd (AM5 + NVMe) ─────────────────────────────────────
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Native Btrfs multi-device, not mdadm.
  boot.swraid.enable = false;

  # ── System pool (nigel-system) — fastest non-spindle drive ──────────
  # Nix store + build scratch always land here. zstd:3 for the store's
  # high-compressibility; noatime; async discard for SSD/NVMe TRIM.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nigel-system";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nigel-system";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/persist" = {
    device = "/dev/disk/by-label/nigel-system";
    fsType = "btrfs";
    options = [ "subvol=@persist" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/var/tmp" = {
    device = "/dev/disk/by-label/nigel-system";
    fsType = "btrfs";
    options = [ "subvol=@build" "compress=zstd:1" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  # ── Home pool (nigel-home) — second SSD if present, else same drive ──
  fileSystems."/home" = {
    device = "/dev/disk/by-label/nigel-home";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  # ── Bulk/cold pool (nigel-bulk) — slowest drive (spindle if present) ─
  # NOTE: no "ssd"/"discard" here — this tier may be a spinning disk.
  fileSystems."/mnt/bulk" = {
    device = "/dev/disk/by-label/nigel-bulk";
    fsType = "btrfs";
    options = [ "subvol=@bulk" "compress=zstd:3" "noatime" "space_cache=v2" "nofail" ];
  };

  fileSystems."/mnt/games" = {
    device = "/dev/disk/by-label/nigel-bulk";
    fsType = "btrfs";
    options = [ "subvol=@games" "compress=zstd:1" "noatime" "space_cache=v2" "nofail" ];
  };

  # ── ESP ──────────────────────────────────────────────────────────────
  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/NIGELESP";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # ── Swap (on the fastest drive, partlabel) ───────────────────────────
  swapDevices = [
    { device = "/dev/disk/by-partlabel/NIGELSWAP"; priority = 100; }
  ];

  # ── Build scratch lives on the fast system pool ──────────────────────
  # Overrides the default my.paths.buildScratch so Nix builds hit NVMe.
  my.paths.buildScratch = "/var/tmp/nix-build";
  nix.settings.build-dir = "/var/tmp/nix-build";
  systemd.tmpfiles.rules = [
    "d /var/tmp/nix-build 0755 root root -"
    "d /mnt/bulk  0755 celes users -"
    "d /mnt/games 0755 celes users -"
  ];

  # ── Platform ─────────────────────────────────────────────────────────
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
