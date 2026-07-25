#!/usr/bin/env bash
# NixOS Installation Script for Parallels Desktop (aarch64)
# Fully automated — static UUIDs match vm/hardware-configuration.nix.
#
# Usage from NixOS installer:
#   nix-shell -p git curl
#   bash <(curl -sL https://raw.githubusercontent.com/celesrenata/nix-flakes/main/vm/setup.sh)

set -euo pipefail

DISK="/dev/sda"
FLAKE_REPO="https://github.com/celesrenata/nix-flakes"
HOSTNAME="nixberry"

# Static UUIDs — must match vm/hardware-configuration.nix
UUID_BTRFS="d497df0a-be76-446f-a04a-611166d738e8"
UUID_ESP="ED09-7DA6"
UUID_SWAP="0457cac8-6d84-4fc0-ad53-b3dbf79ee20f"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  NixOS Parallels VM Installer (aarch64)                     ║"
echo "║  Disk: ${DISK}  Host: ${HOSTNAME}                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  This will WIPE ${DISK} entirely."
read -p "Continue? [y/N] " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

# ── Partition ──────────────────────────────────────────────────────────
echo "▶ Partitioning ${DISK}..."
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
mkfs.fat -F32 -i "${UUID_ESP//-/}" ${DISK}1
mkswap -U "${UUID_SWAP}" ${DISK}2
swapon ${DISK}2
mkfs.btrfs -f -U "${UUID_BTRFS}" ${DISK}3

# ── Create btrfs subvolumes ───────────────────────────────────────────
echo "▶ Creating btrfs subvolumes..."
mount ${DISK}3 /mnt
btrfs subvol create /mnt/root
btrfs subvol create /mnt/home
btrfs subvol create /mnt/nix
btrfs subvol create /mnt/workplace
umount /mnt

# ── Mount ──────────────────────────────────────────────────────────────
echo "▶ Mounting..."
mount -o compress=zstd,subvol=root ${DISK}3 /mnt
mkdir -p /mnt/{boot,nix,home,workplace}
mount -o compress=zstd,subvol=home ${DISK}3 /mnt/home
mount -o compress=zstd,subvol=nix ${DISK}3 /mnt/nix
mount -o compress=zstd,subvol=workplace ${DISK}3 /mnt/workplace
mount ${DISK}1 /mnt/boot

# ── Clone and install ──────────────────────────────────────────────────
echo "▶ Cloning flake..."
nix-shell -p git --run "git clone ${FLAKE_REPO} /mnt/etc/nixos"

echo "▶ Installing NixOS..."
nixos-install --root /mnt --flake /mnt/etc/nixos#${HOSTNAME}

echo ""
echo "✅ Done. Reboot into NixOS."
echo "   Rebuild: sudo nixos-rebuild switch --flake /etc/nixos#nixberry"
