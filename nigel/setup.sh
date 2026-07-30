#!/usr/bin/env bash
# NixOS Installation Script for Nigel (Lenovo ideacentre AIO 700-27ISH)
# Fully automated — generates static UUIDs to match nigel/hardware-configuration.nix.
#
# Usage from NixOS installer USB:
#   bash <(curl -sL https://raw.githubusercontent.com/celesrenata/nix-flakes/main/nigel/setup.sh)
#
# Or from Linux Mint with Nix installed:
#   curl -sL https://raw.githubusercontent.com/celesrenata/nix-flakes/main/nigel/setup.sh | bash

set -euo pipefail

DISK="${1:-/dev/nvme0n1}"
FLAKE_REPO="https://github.com/celesrenata/nix-flakes"
HOSTNAME="nigel"

# Generate static UUIDs — will be written into hardware-configuration.nix
UUID_ROOT="$(uuidgen)"
UUID_ESP="$(uuidgen | head -c 8 | tr '[:lower:]' '[:upper:]')-$(uuidgen | head -c 4 | tr '[:lower:]' '[:upper:]')"
UUID_SWAP="$(uuidgen)"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  NixOS Nigel Installer (Lenovo AIO 700-27ISH)              ║"
echo "║  Disk: ${DISK}  Host: ${HOSTNAME}                          ║"
echo "║  CPU: Intel i7-6700  GPU: NVIDIA GTX 950M                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  This will WIPE ${DISK} entirely."
echo "   Make sure ${DISK} is the correct disk!"
read -p "Continue? [y/N] " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# ── Partition ──────────────────────────────────────────────────────────
echo "▶ Partitioning ${DISK}..."
DISKNAME="${DISK##*/}"
if [[ "$DISK" =~ nvme ]]; then
  PART1="${DISK}p1"
  PART2="${DISK}p2"
  PART3="${DISK}p3"
else
  PART1="${DISK}1"
  PART2="${DISK}2"
  PART3="${DISK}3"
fi

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${DISK}
  g
  n
  p
  1

  +256M
  n
  p
  2

  +8G
  n
  p
  3


  t
  1
  uefi
  t
  2
  swap
  t
  3
  linux
  w
  q
EOF

# ── Format with static UUIDs ──────────────────────────────────────────
echo "▶ Formatting with static UUIDs..."
echo "   Root UUID: ${UUID_ROOT}"
echo "   ESP  UUID: ${UUID_ESP}"
echo "   Swap UUID: ${UUID_SWAP}"

mkfs.fat -F32 -i "$(echo ${UUID_ESP} | sed 's/-//g')" ${PART1}
mkswap -U "${UUID_SWAP}" ${PART2}
swapon ${PART2}
mkfs.btrfs -f -U "${UUID_ROOT}" ${PART3}

# ── Create btr