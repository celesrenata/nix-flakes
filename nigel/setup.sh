#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  nigel/setup.sh — Auto-tiering nuclear NixOS installer for Nigel (AM5)      ║
# ╠═══════════════════════════════════════════════════════════════════════════════╣
# ║                                                                             ║
# ║  Detects every fixed drive, classifies it by speed, and lays out btrfs      ║
# ║  pools so the HOT data (Nix store + build scratch) always lands on the      ║
# ║  FASTEST drive, HOME on the next-fastest SSD, and COLD bulk on the slowest  ║
# ║  drive — but NEVER puts the store/build/home on a spinning disk.            ║
# ║                                                                             ║
# ║  SPEED TIERS (fastest → slowest):                                           ║
# ║    tier 0: NVMe            (/sys name nvme*, rotational=0)                   ║
# ║    tier 1: SATA/SAS SSD    (rotational=0, not nvme)                         ║
# ║    tier 2: spindle (HDD)   (rotational=1)   ← "unless spindle!!!"           ║
# ║                                                                             ║
# ║  PLACEMENT POLICY:                                                          ║
# ║    SYSTEM pool  (btrfs label "nigel-system")  → fastest NON-spindle drive   ║
# ║        @root → /     @nix → /nix     @persist → /persist                    ║
# ║        @build → /var/tmp  (Nix build-dir; always on the fastest drive)      ║
# ║        + ESP + swap live on this drive too.                                 ║
# ║                                                                             ║
# ║    HOME pool    (btrfs label "nigel-home")                                  ║
# ║        @home → /home                                                        ║
# ║        → a SECOND non-spindle (SSD/NVMe) drive if one exists, else          ║
# ║        → the SAME system drive (single-SSD box). NEVER a spindle.           ║
# ║                                                                             ║
# ║    BULK pool    (btrfs label "nigel-bulk")                                  ║
# ║        @bulk → /mnt/bulk     @games → /mnt/games                            ║
# ║        → the SLOWEST drive (a spindle if one is present), else the          ║
# ║          home drive. Spindles ONLY ever host this cold tier.                ║
# ║                                                                             ║
# ║  All three btrfs labels always exist after this script runs, so the         ║
# ║  committed nigel/hardware-configuration.nix (which mounts by-label) works   ║
# ║  unchanged whether nigel has 1, 2, or 3+ drives. On a single-drive box all  ║
# ║  three labels resolve to subvolumes of the one filesystem.                  ║
# ║                                                                             ║
# ║  MODES:                                                                     ║
# ║    (default)   Detect → plan → confirm → NUCLEAR format → create pools      ║
# ║    --mount     Mount the already-formatted pools under /mnt for install     ║
# ║    --plan      Detect + print the tiering plan only (no changes, no root)   ║
# ║    --dry-run   Print every operation without executing it                   ║
# ║                                                                             ║
# ║  WARNING: default mode DESTROYS ALL DATA on every detected fixed drive.     ║
# ║                                                                             ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
#
# Usage:
#   sudo ./nigel/setup.sh --plan            # see what it would do
#   sudo ./nigel/setup.sh --dry-run         # full format run, printed only
#   sudo ./nigel/setup.sh                    # NUCLEAR: format + create pools
#   sudo ./nigel/setup.sh --mount           # mount pools under /mnt
#   then: nixos-install --flake .#nigel
#
# Override auto-detection by passing explicit drives:
#   sudo ./nigel/setup.sh /dev/nvme0n1 /dev/sda

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================
ESP_SIZE="2G"
SWAP_SIZE="32G"           # swap partition on the system (fastest) drive

# btrfs filesystem labels — referenced by nigel/hardware-configuration.nix
SYSTEM_LABEL="nigel-system"
HOME_LABEL="nigel-home"
BULK_LABEL="nigel-bulk"

# partition labels (by-partlabel) for ESP + swap
ESP_PARTLABEL="NIGELESP"
SWAP_PARTLABEL="NIGELSWAP"

SWAP_PRIORITY=100

# Subvolume sets per pool
SYSTEM_SUBVOLS=("@root" "@nix" "@persist" "@build")
HOME_SUBVOLS=("@home")
BULK_SUBVOLS=("@bulk" "@games")

# Mount options
SYS_OPTS="compress=zstd:3,noatime,space_cache=v2,ssd,discard=async"
BUILD_OPTS="compress=zstd:1,noatime,space_cache=v2,ssd,discard=async"
HOME_OPTS="compress=zstd:3,noatime,space_cache=v2,ssd,discard=async"
BULK_OPTS="compress=zstd:3,noatime,space_cache=v2,nofail"      # may be a spindle: no ssd/discard
GAMES_OPTS="compress=zstd:1,noatime,space_cache=v2,nofail"

MNT="/mnt"
TMPMT="/mnt/btrfs-setup"

# =============================================================================
# STATE
# =============================================================================
DRY_RUN=false
MODE="format"            # format | mount | plan
declare -a OVERRIDE_DRIVES=()

# Filled in by detect/plan:
SYSTEM_DRIVE=""          # fastest non-spindle (holds system pool + ESP + swap)
HOME_DRIVE=""            # drive hosting @home (== SYSTEM_DRIVE if single-SSD)
BULK_DRIVE=""            # drive hosting cold bulk (== HOME_DRIVE if no spindle)
HOME_SHARES_SYSTEM=false # true when @home lives on the system filesystem
BULK_SHARES_HOME=false   # true when bulk lives on the home filesystem

# Resolved btrfs label each mountpoint should reference (computed in build_plan).
# On fewer-drive systems these collapse onto nigel-system / nigel-home.
HOME_FS_LABEL="$HOME_LABEL"
BULK_FS_LABEL="$BULK_LABEL"

# =============================================================================
# LOGGING / HELPERS
# =============================================================================
log()       { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }
log_error() { log "ERROR: $*" >&2; }

run_cmd() {
  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY-RUN] $*"
  else
    log "Running: $*"
    "$@"
  fi
}

confirm() {
  local message="$1"
  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY-RUN] Would: $message"
    return 0
  fi
  log "CONFIRM: $message"
  read -r -p "  Proceed? [y/N] " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) log "Aborted by user."; exit 1 ;;
  esac
}

check_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (needs to format drives)."
    exit 1
  fi
}

# Partition suffix: nvme0n1 → nvme0n1p1 ; sda → sda1
part_of() {
  local disk="$1" num="$2"
  if [[ "$disk" =~ nvme|mmcblk|loop ]]; then
    echo "${disk}p${num}"
  else
    echo "${disk}${num}"
  fi
}

# =============================================================================
# DRIVE DETECTION + CLASSIFICATION
# =============================================================================
# Returns the device path currently backing the live installer root, so we
# never wipe the medium we're booted from.
live_root_disk() {
  local src parent
  src="$(findmnt -no SOURCE / 2>/dev/null || true)"
  [[ -z "$src" ]] && return 0
  # Resolve to the parent whole-disk (strip partition).
  parent="$(lsblk -no PKNAME "$src" 2>/dev/null | head -n1 || true)"
  if [[ -n "$parent" ]]; then
    echo "/dev/$parent"
  else
    echo "$src"
  fi
}

# tier for a whole-disk device: 0 nvme, 1 ssd, 2 spindle
drive_tier() {
  local dev="$1" base rot
  base="$(basename "$dev")"
  rot="$(cat "/sys/block/${base}/queue/rotational" 2>/dev/null || echo 0)"
  if [[ "$base" == nvme* ]]; then
    echo 0
  elif [[ "$rot" == "0" ]]; then
    echo 1
  else
    echo 2
  fi
}

drive_size_bytes() {
  local dev="$1"
  lsblk -bdno SIZE "$dev" 2>/dev/null | head -n1 || echo 0
}

drive_model() {
  lsblk -dno MODEL "$1" 2>/dev/null | head -n1 | tr -s ' ' || true
}

tier_name() {
  case "$1" in
    0) echo "NVMe" ;;
    1) echo "SSD" ;;
    2) echo "SPINDLE" ;;
  esac
}

# Discover candidate whole-disk devices, excluding the live medium, removable
# USB sticks, loop/zram/rom. Prints "tier size dev" lines, sorted fastest first.
detect_drives() {
  local live
  live="$(live_root_disk)"

  local -a rows=()
  local name type rm dev tier size
  while read -r name type rm; do
    [[ "$type" == "disk" ]] || continue
    dev="/dev/$name"
    # Skip the live installer disk and removable USB sticks.
    [[ "$dev" == "$live" ]] && continue
    [[ "$rm" == "1" ]] && continue
    # Skip zram / loop / optical just in case lsblk included them.
    case "$name" in zram*|loop*|sr*) continue ;; esac
    tier="$(drive_tier "$dev")"
    size="$(drive_size_bytes "$dev")"
    rows+=("${tier} ${size} ${dev}")
  done < <(lsblk -dno NAME,TYPE,RM)

  # Sort: tier ascending (fast first), then size descending (bigger first).
  printf '%s\n' "${rows[@]}" | sort -k1,1n -k2,2nr
}

human() {
  local b="$1"
  awk -v b="$b" 'BEGIN{
    split("B KB MB GB TB PB",u," ");
    i=1; while (b>=1024 && i<6){b/=1024;i++}
    printf "%.1f%s", b, u[i]
  }'
}

# =============================================================================
# PLANNING — decide which drive hosts which pool
# =============================================================================
build_plan() {
  local -a lines=()
  if [[ ${#OVERRIDE_DRIVES[@]} -gt 0 ]]; then
    local d tier size
    for d in "${OVERRIDE_DRIVES[@]}"; do
      [[ -b "$d" ]] || { log_error "$d is not a block device"; exit 1; }
      tier="$(drive_tier "$d")"
      size="$(drive_size_bytes "$d")"
      lines+=("${tier} ${size} ${d}")
    done
    # Preserve user order but still prefer non-spindles for system; sort by tier.
    mapfile -t lines < <(printf '%s\n' "${lines[@]}" | sort -k1,1n -k2,2nr)
  else
    mapfile -t lines < <(detect_drives)
  fi

  if [[ ${#lines[@]} -eq 0 ]]; then
    log_error "No eligible fixed drives detected. Pass drives explicitly, e.g.:"
    log_error "  sudo $0 /dev/nvme0n1"
    lsblk -dno NAME,SIZE,MODEL,ROTA 2>/dev/null || true
    exit 1
  fi

  # Parse into parallel arrays.
  local -a DEV=() TIER=() SIZE=()
  local line
  for line in "${lines[@]}"; do
    TIER+=("$(awk '{print $1}' <<<"$line")")
    SIZE+=("$(awk '{print $2}' <<<"$line")")
    DEV+=("$(awk '{print $3}' <<<"$line")")
  done

  log "Detected drives (fastest first):"
  local i
  for i in "${!DEV[@]}"; do
    log "  [$i] ${DEV[$i]}  $(tier_name "${TIER[$i]}")  $(human "${SIZE[$i]}")  $(drive_model "${DEV[$i]}")"
  done

  # SYSTEM drive = first NON-spindle (tier < 2). Fall back to the only drive.
  local sys_idx=-1
  for i in "${!DEV[@]}"; do
    if [[ "${TIER[$i]}" -lt 2 ]]; then sys_idx=$i; break; fi
  done
  if [[ $sys_idx -lt 0 ]]; then
    log "WARNING: no SSD/NVMe found — the ONLY drive(s) are spindles."
    log "         Installing the Nix store on a spinning disk is slow but"
    log "         unavoidable with this hardware. Using the largest spindle."
    sys_idx=0
  fi
  SYSTEM_DRIVE="${DEV[$sys_idx]}"

  # HOME drive = next non-spindle different from system; else system drive.
  local home_idx=-1
  for i in "${!DEV[@]}"; do
    [[ $i -eq $sys_idx ]] && continue
    if [[ "${TIER[$i]}" -lt 2 ]]; then home_idx=$i; break; fi
  done
  if [[ $home_idx -lt 0 ]]; then
    HOME_DRIVE="$SYSTEM_DRIVE"
    HOME_SHARES_SYSTEM=true
  else
    HOME_DRIVE="${DEV[$home_idx]}"
    HOME_SHARES_SYSTEM=false
  fi

  # BULK drive = slowest drive not already used as system; prefer a spindle.
  # Pick the LAST entry (slowest) that isn't the system drive.
  local bulk_idx=-1
  for ((i=${#DEV[@]}-1; i>=0; i--)); do
    [[ $i -eq $sys_idx ]] && continue
    bulk_idx=$i; break
  done
  if [[ $bulk_idx -lt 0 ]]; then
    # Only one drive total → bulk shares home (which shares system).
    BULK_DRIVE="$HOME_DRIVE"
    BULK_SHARES_HOME=true
  else
    BULK_DRIVE="${DEV[$bulk_idx]}"
    # If the chosen bulk drive is the same device as home, mark it shared.
    if [[ "$BULK_DRIVE" == "$HOME_DRIVE" ]]; then
      BULK_SHARES_HOME=true
    else
      BULK_SHARES_HOME=false
    fi
  fi

  # Safety: a spindle must NEVER be the system or home drive.
  if [[ "$(drive_tier "$SYSTEM_DRIVE")" == "2" && $sys_idx -ge 0 && ${#DEV[@]} -gt 1 ]]; then
    log_error "Refusing to place the system pool on a spindle while an SSD exists."
    exit 1
  fi
  if [[ "$HOME_SHARES_SYSTEM" == false && "$(drive_tier "$HOME_DRIVE")" == "2" ]]; then
    # Never dedicate a spindle to /home — fold it back onto the system drive.
    log "NOTE: candidate home drive is a spindle; keeping /home on the system drive instead."
    HOME_DRIVE="$SYSTEM_DRIVE"
    HOME_SHARES_SYSTEM=true
  fi

  # Resolve which real btrfs label each tier ends up on (collapses on shared drives).
  if [[ "$HOME_SHARES_SYSTEM" == true ]]; then
    HOME_FS_LABEL="$SYSTEM_LABEL"
  else
    HOME_FS_LABEL="$HOME_LABEL"
  fi
  if [[ "$BULK_SHARES_HOME" == true ]]; then
    BULK_FS_LABEL="$HOME_FS_LABEL"
  else
    BULK_FS_LABEL="$BULK_LABEL"
  fi

  echo ""
  log "╔════════════════════════ TIERING PLAN ════════════════════════╗"
  log "  SYSTEM pool ($SYSTEM_LABEL)  → $SYSTEM_DRIVE  [$(tier_name "$(drive_tier "$SYSTEM_DRIVE")")]"
  log "      /  /nix  /persist  /var/tmp(build) + ESP + ${SWAP_SIZE} swap"
  if [[ "$HOME_SHARES_SYSTEM" == true ]]; then
    log "  HOME pool   ($HOME_LABEL)  → (shares $SYSTEM_DRIVE — no 2nd SSD)"
  else
    log "  HOME pool   ($HOME_LABEL)  → $HOME_DRIVE  [$(tier_name "$(drive_tier "$HOME_DRIVE")")]"
    log "      /home"
  fi
  if [[ "$BULK_SHARES_HOME" == true ]]; then
    log "  BULK pool   ($BULK_LABEL)  → (shares $HOME_DRIVE — no spindle/extra drive)"
  else
    log "  BULK pool   ($BULK_LABEL)  → $BULK_DRIVE  [$(tier_name "$(drive_tier "$BULK_DRIVE")")]"
    log "      /mnt/bulk  /mnt/games"
  fi
  log "╚═══════════════════════════════════════════════════════════════╝"
  echo ""
}

# =============================================================================
# HARDWARE-CONFIG GENERATION
# =============================================================================
# Rewrites nigel/hardware-configuration.nix fileSystems/swap to match the
# ACTUAL topology just built, so the persistent (committed) config boots on
# any drive count. The committed default documents the dual-NVMe case; this
# collapses mounts onto the right labels for 1/2/3+ drive machines.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HWCONF="${SCRIPT_DIR}/hardware-configuration.nix"

generate_hw_config() {
  local out="${1:-$HWCONF}"
  log "Generating hardware-configuration.nix fileSystems for the detected layout → $out"

  local body
  body="$(cat <<EOF
# GENERATED by nigel/setup.sh — fileSystems match the drives it detected.
# Re-run 'sudo ./nigel/setup.sh --plan' to see the tiering; edit the modules in
# this directory for everything else. Regenerate by re-running setup.sh.
#
# System drive : ${SYSTEM_DRIVE}
# Home   drive : ${HOME_DRIVE}$( [[ "$HOME_SHARES_SYSTEM" == true ]] && echo " (shares system fs)")
# Bulk   drive : ${BULK_DRIVE}$( [[ "$BULK_SHARES_HOME" == true ]] && echo " (shares $( [[ "$HOME_SHARES_SYSTEM" == true ]] && echo system || echo home) fs)")

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.swraid.enable = false;

  fileSystems."/" = {
    device = "/dev/disk/by-label/${SYSTEM_LABEL}";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/${SYSTEM_LABEL}";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };
  fileSystems."/persist" = {
    device = "/dev/disk/by-label/${SYSTEM_LABEL}";
    fsType = "btrfs";
    options = [ "subvol=@persist" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };
  fileSystems."/var/tmp" = {
    device = "/dev/disk/by-label/${SYSTEM_LABEL}";
    fsType = "btrfs";
    options = [ "subvol=@build" "compress=zstd:1" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/${HOME_FS_LABEL}";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd:3" "noatime" "space_cache=v2" "ssd" "discard=async" ];
  };

  fileSystems."/mnt/bulk" = {
    device = "/dev/disk/by-label/${BULK_FS_LABEL}";
    fsType = "btrfs";
    options = [ "subvol=@bulk" "compress=zstd:3" "noatime" "space_cache=v2" "nofail" ];
  };
  fileSystems."/mnt/games" = {
    device = "/dev/disk/by-label/${BULK_FS_LABEL}";
    fsType = "btrfs";
    options = [ "subvol=@games" "compress=zstd:1" "noatime" "space_cache=v2" "nofail" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/${ESP_PARTLABEL}";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-partlabel/${SWAP_PARTLABEL}"; priority = ${SWAP_PRIORITY}; }
  ];

  my.paths.buildScratch = "/var/tmp/nix-build";
  nix.settings.build-dir = "/var/tmp/nix-build";
  systemd.tmpfiles.rules = [
    "d /var/tmp/nix-build 0755 root root -"
    "d /mnt/bulk  0755 celes users -"
    "d /mnt/games 0755 celes users -"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
EOF
)"

  if [[ "$DRY_RUN" == true ]]; then
    log "[DRY-RUN] Would write the following to $out:"
    echo "$body"
  else
    printf '%s\n' "$body" > "$out"
    log "Wrote $out — review and commit it (git flow)."
  fi
}

# =============================================================================
# FORMAT MODE
# =============================================================================
# Partition the system drive: p1=ESP p2=swap p3=system-btrfs(rest)
partition_system_drive() {
  local disk="$1"
  confirm "NUCLEAR: wipe $disk and partition (ESP ${ESP_SIZE} + swap ${SWAP_SIZE} + btrfs rest)"
  run_cmd sgdisk --zap-all "$disk"
  run_cmd sgdisk \
    --new=1:0:+"${ESP_SIZE}"  --typecode=1:EF00 --change-name=1:"${ESP_PARTLABEL}" \
    --new=2:0:+"${SWAP_SIZE}" --typecode=2:8200 --change-name=2:"${SWAP_PARTLABEL}" \
    --new=3:0:0               --typecode=3:8300 --change-name=3:"${SYSTEM_LABEL}" \
    "$disk"
  run_cmd partprobe "$disk"
}

# Partition a secondary (home or bulk) drive as a single btrfs partition.
partition_data_drive() {
  local disk="$1" partlabel="$2"
  confirm "NUCLEAR: wipe $disk and make one btrfs partition ($partlabel)"
  run_cmd sgdisk --zap-all "$disk"
  run_cmd sgdisk --new=1:0:0 --typecode=1:8300 --change-name=1:"${partlabel}" "$disk"
  run_cmd partprobe "$disk"
}

create_subvols_on() {
  local device="$1"; shift
  local -a subvols=("$@")
  if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$TMPMT"
    mount "$device" "$TMPMT"
  else
    log "[DRY-RUN] mount $device $TMPMT"
  fi
  local sv
  for sv in "${subvols[@]}"; do
    run_cmd btrfs subvolume create "${TMPMT}/${sv}"
  done
  if [[ "$DRY_RUN" == false ]]; then
    umount "$TMPMT"; rmdir "$TMPMT"
  else
    log "[DRY-RUN] umount $TMPMT"
  fi
}

do_format() {
  log "=== FORMAT MODE (NUCLEAR) ==="
  build_plan

  # Compose the full subvol set for the system filesystem (adds @home / bulk
  # subvols when those tiers share the system drive).
  local -a sys_subvols=("${SYSTEM_SUBVOLS[@]}")
  if [[ "$HOME_SHARES_SYSTEM" == true ]]; then
    sys_subvols+=("${HOME_SUBVOLS[@]}")
  fi
  if [[ "$HOME_SHARES_SYSTEM" == true && "$BULK_SHARES_HOME" == true ]]; then
    sys_subvols+=("${BULK_SUBVOLS[@]}")
  fi

  # --- System drive: partition, ESP, swap, system btrfs ---
  log "--- System drive: $SYSTEM_DRIVE ---"
  partition_system_drive "$SYSTEM_DRIVE"
  local sys_p1 sys_p2 sys_p3
  sys_p1="$(part_of "$SYSTEM_DRIVE" 1)"
  sys_p2="$(part_of "$SYSTEM_DRIVE" 2)"
  sys_p3="$(part_of "$SYSTEM_DRIVE" 3)"

  confirm "Format ESP on $sys_p1 and swap on $sys_p2"
  run_cmd mkfs.vfat -F 32 -n "ESP" "$sys_p1"
  run_cmd mkswap -L "SWAP" "$sys_p2"

  confirm "Create system btrfs ($SYSTEM_LABEL) on $sys_p3"
  run_cmd mkfs.btrfs -f -L "$SYSTEM_LABEL" "$sys_p3"
  create_subvols_on "$sys_p3" "${sys_subvols[@]}"

  # --- Home drive (only if dedicated) ---
  if [[ "$HOME_SHARES_SYSTEM" == false ]]; then
    log "--- Home drive: $HOME_DRIVE ---"
    partition_data_drive "$HOME_DRIVE" "$HOME_LABEL"
    local home_p1; home_p1="$(part_of "$HOME_DRIVE" 1)"
    local -a home_subvols=("${HOME_SUBVOLS[@]}")
    # If bulk also shares the home drive (home SSD + no spindle), add bulk subvols here.
    if [[ "$BULK_SHARES_HOME" == true ]]; then
      home_subvols+=("${BULK_SUBVOLS[@]}")
    fi
    confirm "Create home btrfs ($HOME_LABEL) on $home_p1"
    run_cmd mkfs.btrfs -f -L "$HOME_LABEL" "$home_p1"
    create_subvols_on "$home_p1" "${home_subvols[@]}"
  fi

  # --- Bulk drive (only if dedicated / separate device) ---
  if [[ "$BULK_SHARES_HOME" == false ]]; then
    log "--- Bulk drive: $BULK_DRIVE ---"
    partition_data_drive "$BULK_DRIVE" "$BULK_LABEL"
    local bulk_p1; bulk_p1="$(part_of "$BULK_DRIVE" 1)"
    confirm "Create bulk btrfs ($BULK_LABEL) on $bulk_p1"
    run_cmd mkfs.btrfs -f -L "$BULK_LABEL" "$bulk_p1"
    create_subvols_on "$bulk_p1" "${BULK_SUBVOLS[@]}"
  fi

  echo ""
  generate_hw_config

  echo ""
  log "╔═══════════════════════════════════════════════════════════════╗"
  log "║  FORMAT COMPLETE                                              ║"
  log "║  Labels created: $SYSTEM_LABEL $HOME_LABEL $BULK_LABEL        "
  log "║  (shared labels point at the same fs on fewer-drive systems)  ║"
  log "║  Next: sudo $0 --mount                                        "
  log "║  Then: nixos-install --flake .#nigel                          ║"
  log "╚═══════════════════════════════════════════════════════════════╝"

  if [[ "$DRY_RUN" == false ]]; then
    log "Verification:"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$SYSTEM_DRIVE" \
      "$([[ "$HOME_SHARES_SYSTEM" == false ]] && echo "$HOME_DRIVE")" \
      "$([[ "$BULK_SHARES_HOME" == false ]] && echo "$BULK_DRIVE")" 2>/dev/null || true
  fi
}

# =============================================================================
# MOUNT MODE — mount by label under /mnt for nixos-install
# =============================================================================
do_mount() {
  log "=== MOUNT MODE ==="
  build_plan

  local sys="/dev/disk/by-label/${SYSTEM_LABEL}"
  local home="/dev/disk/by-label/${HOME_FS_LABEL}"
  local bulk="/dev/disk/by-label/${BULK_FS_LABEL}"

  log "Mounting system pool..."
  run_cmd mount -o "subvol=@root,${SYS_OPTS}" "$sys" "$MNT"
  run_cmd mkdir -p "$MNT/nix" "$MNT/persist" "$MNT/var/tmp" "$MNT/home" \
                   "$MNT/boot" "$MNT/mnt/bulk" "$MNT/mnt/games"
  run_cmd mount -o "subvol=@nix,${SYS_OPTS}"     "$sys" "$MNT/nix"
  run_cmd mount -o "subvol=@persist,${SYS_OPTS}" "$sys" "$MNT/persist"
  run_cmd mount -o "subvol=@build,${BUILD_OPTS}" "$sys" "$MNT/var/tmp"

  log "Mounting ESP..."
  run_cmd mount "/dev/disk/by-partlabel/${ESP_PARTLABEL}" "$MNT/boot"

  log "Mounting home pool (by label — same fs as system on single-SSD boxes)..."
  run_cmd mount -o "subvol=@home,${HOME_OPTS}" "$home" "$MNT/home"

  log "Mounting bulk pool..."
  run_cmd mount -o "subvol=@bulk,${BULK_OPTS}"   "$bulk" "$MNT/mnt/bulk"
  run_cmd mount -o "subvol=@games,${GAMES_OPTS}" "$bulk" "$MNT/mnt/games"

  log "Activating swap..."
  run_cmd swapon -p "$SWAP_PRIORITY" "/dev/disk/by-partlabel/${SWAP_PARTLABEL}"

  echo ""
  log "╔═══════════════════════════════════════════════════════════════╗"
  log "║  ALL MOUNTED UNDER ${MNT}                                      "
  log "║  Ready for: nixos-install --flake .#nigel                     ║"
  log "╚═══════════════════════════════════════════════════════════════╝"

  if [[ "$DRY_RUN" == false ]]; then
    findmnt --target "$MNT" --tree 2>/dev/null || mount | grep "$MNT"
  fi
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      --mount)   MODE="mount"; shift ;;
      --plan)    MODE="plan"; DRY_RUN=true; shift ;;
      --emit-hwconfig) MODE="emit"; DRY_RUN=true; shift ;;
      -h|--help)
        sed -n '2,60p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
        ;;
      /dev/*)    OVERRIDE_DRIVES+=("$1"); shift ;;
      *) log_error "Unknown argument: $1"; exit 1 ;;
    esac
  done
}

# =============================================================================
# MAIN
# =============================================================================
main() {
  parse_args "$@"

  case "$MODE" in
    plan)
      build_plan
      ;;
    emit)
      build_plan
      generate_hw_config /dev/stdout
      ;;
    format)
      [[ "$DRY_RUN" == false ]] && check_root
      do_format
      ;;
    mount)
      [[ "$DRY_RUN" == false ]] && check_root
      do_mount
      ;;
  esac
}

main "$@"
