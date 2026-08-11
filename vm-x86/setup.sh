#!/usr/bin/env bash
# NixOS Installation Script for VirtualBox/VMware (x86_64)
# Fully automated — static UUIDs match vm-x86/hardware-configuration.nix.
#
# Usage from NixOS installer:
#   nix-shell -p git curl
#   bash <(curl -sL https://raw.githubusercontent.com/celesrenata/nix-flakes/main/vm-x86/setup.sh)

set -euo pipefail

DISK="/dev/sda"
FLAKE_REPO="https://github.com/celesrenata/nix-flakes"
HOSTNAME="nixbox"

# Static UUIDs — must match vm-x86/hardware-configuration.nix
UUID_BTRFS="a1b2c3d4-e5f6-7890-abcd-ef1234567890"
UUID_ESP="ABCD-1234"
UUID_SWAP="12345678-abcd-ef01-2345-6789abcdef01"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  NixOS VirtualBox/VMware VM Installer (x86_64)              ║"
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

  +512M
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
echo "   Rebuild: sudo nixos-rebuild switch --flake /etc/nixos#nixbox"
