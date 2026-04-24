#!/usr/bin/env bash
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  rebuild-storage-layout.sh — Full NVMe Setup for esnixi (DESTRUCTIVE)       ║
# ╠═══════════════════════════════════════════════════════════════════════════════╣
# ║                                                                             ║
# ║  DRIVE LAYOUT (both NVMe drives partitioned identically):                   ║
# ║                                                                             ║
# ║  /dev/nvme0n1                        /dev/nvme1n1                           ║
# ║  ┌──────────────────────────┐        ┌──────────────────────────┐           ║
# ║  │ p1: ESP0       2G  vfat │        │ p1: ESP1       2G  vfat │           ║
# ║  │ p2: SWAP0     32G  swap │        │ p2: SWAP1     32G  swap │           ║
# ║  │ p3: SYSTEM0    2T  btrfs│        │ p3: SYSTEM1    2T  btrfs│           ║
# ║  │ p4: FAST0    rest  btrfs│        │ p4: FAST1    rest  btrfs│           ║
# ║  └──────────────────────────┘        └──────────────────────────┘           ║
# ║                                                                             ║
# ║  BTRFS POOLS:                                                               ║
# ║    esnixi-system  (p3+p3)  data=raid1  meta=raid1  (mirrored, safe)        ║
# ║    esnixi-fast    (p4+p4)  data=raid0  meta=raid1  (striped, fast)         ║
# ║                                                                             ║
# ║  SYSTEM POOL SUBVOLUMES (esnixi-system):                                   ║
# ║    @root     → /                                                            ║
# ║    @home     → /home                                                        ║
# ║    @nix      → /nix                                                         ║
# ║    @persist  → /persist                                                     ║
# ║                                                                             ║
# ║  FAST POOL SUBVOLUMES (esnixi-fast):                                       ║
# ║    @var-lib-docker  → /var/lib/docker                                       ║
# ║    @var-lib-ollama  → /var/lib/ollama                                       ║
# ║    @var-lib-vllm    → /var/lib/vllm                                         ║
# ║    @var-tmp         → /var/tmp                                              ║
# ║    @fast            → /mnt/fast       (general fast scratch)                ║
# ║    @games           → /mnt/games                                            ║
# ║                                                                             ║
# ║  SWAP:                                                                      ║
# ║    SWAP0 + SWAP1 at equal priority 100 (kernel stripes natively)            ║
# ║                                                                             ║
# ║  MOUNT OPTIONS (in hardware-configuration.nix):                             ║
# ║    System pool: compress=zstd:3 noatime space_cache=v2 ssd discard=async   ║
# ║    Fast pool:   compress=zstd:1 noatime space_cache=v2 ssd discard=async   ║
# ║    ESP:         fmask=0022 dmask=0022                                       ║
# ║                                                                             ║
# ║  UUIDs:                                                                     ║
# ║    Btrfs UUIDs are set deterministically via mkfs.btrfs -U so that          ║
# ║    hardware-configuration.nix can be written before formatting.             ║
# ║    Swap and ESP use partlabels (SWAP0, SWAP1, ESP0) instead of UUIDs.      ║
# ║                                                                             ║
# ║  MODES:                                                                     ║
# ║    (default)   Format drives, create pools, create subvolumes               ║
# ║    --mount     Mount everything under /mnt for NixOS installation           ║
# ║    --dry-run   Print planned operations without executing                   ║
# ║                                                                             ║
# ║  WARNING: Default mode DESTROYS all data on both NVMe drives.              ║
# ║                                                                             ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
#
# Usage:
#   sudo ./scripts/rebuild-storage-layout.sh [--dry-run]
#   sudo ./scripts/rebuild-storage-layout.sh --mount [--dry-run]

set -euo pipefail

# =============================================================================
# DRIVE CONFIGURATION
# =============================================================================
NVME_0="/dev/nvme0n1"
NVME_1="/dev/nvme1n1"

# Partition sizes
ESP_SIZE="2G"
SWAP_SIZE="32G"
SYSTEM_SIZE="2T"
# FAST = remainder (no explicit size)

# Partition labels (used by hardware-configuration.nix via by-partlabel)
ESP0_LABEL="ESP0"
ESP1_LABEL="ESP1"
SWAP0_LABEL="SWAP0"
SWAP1_LABEL="SWAP1"
SYSTEM0_LABEL="SYSTEM0"
SYSTEM1_LABEL="SYSTEM1"
FAST0_LABEL="FAST0"
FAST1_LABEL="FAST1"

# Predetermined Btrfs UUIDs — these are baked into hardware-configuration.nix
# so the config can be written before formatting. Generate new ones with `uuidgen`.
SYSTEM_BTRFS_UUID="a1b2c3d4-1111-2222-3333-444455556666"
FAST_BTRFS_UUID="a1b2c3d4-7777-8888-9999-aaabbbcccddd"

# Btrfs labels
SYSTEM_LABEL="esnixi-system"
FAST_LABEL="esnixi-fast"

# Swap priority
SWAP_PRIORITY=100

# System pool subvolumes
SYSTEM_SUBVOLS=("@root" "@home" "@nix" "@persist")

# Fast pool subvolumes
FAST_SUBVOLS=("@var-lib-docker" "@var-lib-ollama" "@var-lib-vllm" "@var-tmp" "@fast" "@games")

# Mount target for --mount mode
MNT="/mnt"

# Temp mount point for subvolume creation
TMPMT="/mnt/btrfs-setup"

# =============================================================================
# STATE
# =============================================================================
DRY_RUN=false
MODE="format"   # "format" or "mount"

# =============================================================================
# LOGGING
# =============================================================================
log()       { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"; }
log_error() { log "ERROR: $*" >&2; }

# =============================================================================
# HELPERS
# =============================================================================
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
    log_error "This script must be run as root."
    exit 1
  fi
}

check_drive() {
  local d="$1"
  if [[ ! -b "$d" ]]; then
    log_error "$d does not exist or is not a block device."
    lsblk -d -o NAME,SIZE,MODEL 2>/dev/null | grep nvme || true
    exit 1
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
      -h|--help)
        cat <<'EOF'
Usage: sudo ./scripts/rebuild-storage-layout.sh [OPTIONS]

Modes:
  (default)    Format both NVMe drives and create Btrfs pools + subvolumes
  --mount      Mount the already-formatted pools under /mnt for NixOS install

Options:
  --dry-run    Print planned operations without executing
  -h, --help   Show this help

See the header of this script for the full drive layout diagram.
EOF
        exit 0
        ;;
      *) log_error "Unknown argument: $1"; exit 1 ;;
    esac
  done
}

# =============================================================================
# FORMAT MODE
# =============================================================================
partition_drive() {
  local drive="$1"
  local esp_label="$2" swap_label="$3" sys_label="$4" fast_label="$5"

  confirm "Wipe and partition $drive (ESP ${ESP_SIZE} + SWAP ${SWAP_SIZE} + SYSTEM ${SYSTEM_SIZE} + FAST rest)"

  run_cmd sgdisk --zap-all "$drive"
  run_cmd sgdisk \
    --new=1:0:+"${ESP_SIZE}"    --typecode=1:EF00 --change-name=1:"${esp_label}" \
    --new=2:0:+"${SWAP_SIZE}"   --typecode=2:8200 --change-name=2:"${swap_label}" \
    --new=3:0:+"${SYSTEM_SIZE}" --typecode=3:8300 --change-name=3:"${sys_label}" \
    --new=4:0:0                 --typecode=4:8300 --change-name=4:"${fast_label}" \
    "$drive"
  run_cmd partprobe "$drive"
  log "Partitioned $drive: p1=${esp_label} p2=${swap_label} p3=${sys_label} p4=${fast_label}"
}

create_esp() {
  confirm "Format ESP on ${NVME_0}p1"
  run_cmd mkfs.vfat -F 32 -n "${ESP0_LABEL}" "${NVME_0}p1"
  log "ESP formatted on ${NVME_0}p1 (${ESP1_LABEL} on ${NVME_1}p1 is a spare)"
}

create_system_pool() {
  confirm "Create system pool (raid1/raid1) on ${NVME_0}p3 + ${NVME_1}p3 with UUID ${SYSTEM_BTRFS_UUID}"
  run_cmd mkfs.btrfs -f \
    -L "${SYSTEM_LABEL}" \
    -U "${SYSTEM_BTRFS_UUID}" \
    -d raid1 -m raid1 \
    "${NVME_0}p3" "${NVME_1}p3"
  log "System pool created: label=${SYSTEM_LABEL} uuid=${SYSTEM_BTRFS_UUID} data=raid1 meta=raid1"
}

create_fast_pool() {
  confirm "Create fast pool (raid0/raid1) on ${NVME_0}p4 + ${NVME_1}p4 with UUID ${FAST_BTRFS_UUID}"
  run_cmd mkfs.btrfs -f \
    -L "${FAST_LABEL}" \
    -U "${FAST_BTRFS_UUID}" \
    -d raid0 -m raid1 \
    "${NVME_0}p4" "${NVME_1}p4"
  log "Fast pool created: label=${FAST_LABEL} uuid=${FAST_BTRFS_UUID} data=raid0 meta=raid1"
}

create_subvolumes_on() {
  local device="$1" label="$2"
  shift 2
  local subvols=("$@")

  if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$TMPMT"
    mount "$device" "$TMPMT"
  else
    log "[DRY-RUN] mount $device $TMPMT"
  fi

  for sv in "${subvols[@]}"; do
    run_cmd btrfs subvolume create "${TMPMT}/${sv}"
    log "  ${label}: created subvolume ${sv}"
  done

  if [[ "$DRY_RUN" == false ]]; then
    umount "$TMPMT"
    rmdir "$TMPMT"
  else
    log "[DRY-RUN] umount $TMPMT"
  fi
}

setup_swap() {
  confirm "Format swap partitions"
  run_cmd mkswap -L "${SWAP0_LABEL}" "${NVME_0}p2"
  run_cmd mkswap -L "${SWAP1_LABEL}" "${NVME_1}p2"
  log "Swap formatted: ${SWAP0_LABEL} + ${SWAP1_LABEL}"
}

do_format() {
  log "=== FORMAT MODE ==="
  log ""
  log "  NVMe 0:            $NVME_0"
  log "  NVMe 1:            $NVME_1"
  log "  System pool UUID:  $SYSTEM_BTRFS_UUID"
  log "  Fast pool UUID:    $FAST_BTRFS_UUID"
  log "  Dry run:           $DRY_RUN"
  log ""

  if [[ "$DRY_RUN" == false ]]; then
    check_drive "$NVME_0"
    check_drive "$NVME_1"
  fi

  log "--- Step 1/6: Partitioning ---"
  partition_drive "$NVME_0" "$ESP0_LABEL" "$SWAP0_LABEL" "$SYSTEM0_LABEL" "$FAST0_LABEL"
  partition_drive "$NVME_1" "$ESP1_LABEL" "$SWAP1_LABEL" "$SYSTEM1_LABEL" "$FAST1_LABEL"

  log "--- Step 2/6: ESP ---"
  create_esp

  log "--- Step 3/6: System pool (raid1/raid1) ---"
  create_system_pool

  log "--- Step 4/6: System subvolumes ---"
  create_subvolumes_on "${NVME_0}p3" "system" "${SYSTEM_SUBVOLS[@]}"

  log "--- Step 5/6: Fast pool (raid0/raid1) ---"
  create_fast_pool

  log "--- Step 6/6: Fast subvolumes ---"
  create_subvolumes_on "${NVME_0}p4" "fast" "${FAST_SUBVOLS[@]}"

  log ""
  log "--- Swap ---"
  setup_swap

  log ""
  log "╔═══════════════════════════════════════════════════════════════════════╗"
  log "║  FORMAT COMPLETE                                                     ║"
  log "╠═══════════════════════════════════════════════════════════════════════╣"
  log "║                                                                      ║"
  log "║  System Btrfs UUID:  ${SYSTEM_BTRFS_UUID}  ║"
  log "║  Fast Btrfs UUID:    ${FAST_BTRFS_UUID}  ║"
  log "║                                                                      ║"
  log "║  These UUIDs are predetermined — they match hardware-configuration.  ║"
  log "║                                                                      ║"
  log "║  Next: sudo $0 --mount                                ║"
  log "║  Then: nixos-install --flake .#esnixi                                ║"
  log "║                                                                      ║"
  log "╚═══════════════════════════════════════════════════════════════════════╝"

  if [[ "$DRY_RUN" == false ]]; then
    log ""
    log "Verification:"
    blkid "${NVME_0}p3" "${NVME_1}p3" "${NVME_0}p4" "${NVME_1}p4" "${NVME_0}p2" "${NVME_1}p2" "${NVME_0}p1" 2>/dev/null || true
  fi
}

# =============================================================================
# MOUNT MODE — mount everything under /mnt for nixos-install
# =============================================================================
do_mount() {
  log "=== MOUNT MODE ==="
  log ""
  log "  Mounting all subvolumes under ${MNT} for NixOS installation."
  log "  Dry run: $DRY_RUN"
  log ""

  local sys_dev="/dev/disk/by-uuid/${SYSTEM_BTRFS_UUID}"
  local fast_dev="/dev/disk/by-uuid/${FAST_BTRFS_UUID}"
  local sys_opts="compress=zstd:3,noatime,space_cache=v2,ssd,discard=async"
  local fast_opts="compress=zstd:1,noatime,space_cache=v2,ssd,discard=async"

  # Root first
  log "Mounting system pool subvolumes..."
  run_cmd mount -o "subvol=@root,${sys_opts}" "$sys_dev" "${MNT}"

  run_cmd mkdir -p "${MNT}/home" "${MNT}/nix" "${MNT}/persist" "${MNT}/boot"
  run_cmd mount -o "subvol=@home,${sys_opts}"    "$sys_dev" "${MNT}/home"
  run_cmd mount -o "subvol=@nix,${sys_opts}"     "$sys_dev" "${MNT}/nix"
  run_cmd mount -o "subvol=@persist,${sys_opts}" "$sys_dev" "${MNT}/persist"

  # ESP
  run_cmd mount "/dev/disk/by-partlabel/${ESP0_LABEL}" "${MNT}/boot"

  # Fast pool
  log "Mounting fast pool subvolumes..."
  run_cmd mkdir -p \
    "${MNT}/var/lib/docker" \
    "${MNT}/var/lib/ollama" \
    "${MNT}/var/lib/vllm" \
    "${MNT}/var/tmp" \
    "${MNT}/mnt/fast" \
    "${MNT}/mnt/games"

  run_cmd mount -o "subvol=@var-lib-docker,${fast_opts}" "$fast_dev" "${MNT}/var/lib/docker"
  run_cmd mount -o "subvol=@var-lib-ollama,${fast_opts}" "$fast_dev" "${MNT}/var/lib/ollama"
  run_cmd mount -o "subvol=@var-lib-vllm,${fast_opts}"   "$fast_dev" "${MNT}/var/lib/vllm"
  run_cmd mount -o "subvol=@var-tmp,${fast_opts}"         "$fast_dev" "${MNT}/var/tmp"
  run_cmd mount -o "subvol=@fast,${fast_opts}"            "$fast_dev" "${MNT}/mnt/fast"
  run_cmd mount -o "subvol=@games,${fast_opts}"           "$fast_dev" "${MNT}/mnt/games"

  # Swap
  log "Activating swap..."
  run_cmd swapon -p "${SWAP_PRIORITY}" "/dev/disk/by-partlabel/${SWAP0_LABEL}"
  run_cmd swapon -p "${SWAP_PRIORITY}" "/dev/disk/by-partlabel/${SWAP1_LABEL}"

  log ""
  log "╔═══════════════════════════════════════════════════════════════════════╗"
  log "║  ALL MOUNTED UNDER ${MNT}                                            ║"
  log "║                                                                      ║"
  log "║  Ready for: nixos-install --flake .#esnixi                           ║"
  log "╚═══════════════════════════════════════════════════════════════════════╝"

  if [[ "$DRY_RUN" == false ]]; then
    log ""
    log "Current mounts:"
    findmnt --target "${MNT}" --tree 2>/dev/null || mount | grep "${MNT}"
  fi
}

# =============================================================================
# MAIN
# =============================================================================
main() {
  parse_args "$@"

  if [[ "$DRY_RUN" == false ]]; then
    check_root
  fi

  case "$MODE" in
    format) do_format ;;
    mount)  do_mount ;;
  esac
}

main "$@"
