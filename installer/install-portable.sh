#!/usr/bin/env bash
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
need_root() { [ "$(id -u)" = 0 ] || die "run this from the NixOS installer as root"; }
ask_bool() { local reply; read -r -p "$1 [y/N] " reply; [[ "$reply" =~ ^[Yy]$ ]]; }

need_root
command -v lsblk >/dev/null || die "lsblk is required"
command -v jq >/dev/null || die "jq is required"

repo="$(cd "$(dirname "$0")/.." && pwd)"
printf '\nPortable end-4 installer\n\n'
printf 'This installer installs the portable profile only: no remote-build, SOPS, vLLM, Arcane, Hyte, or esnixi-only services.\n\n'

mapfile -t disks < <(lsblk -J -d -o NAME,PATH,SIZE,TYPE,ROTA,TRAN,MODEL | jq -r '
  .blockdevices[] | select(.type == "disk") |
  [.path, .size, (if .rota == false then "SSD/NVMe" else "HDD" end), (.tran // ""), (.model // "")] | @tsv' |
  awk -F '\t' '{ score=($3=="SSD/NVMe" ? 0 : 1); print score "\t" $0 }' | sort -n | cut -f2-)
[ "${#disks[@]}" -gt 0 ] || die "no installable disks found"
printf 'Disks, ranked for the NixOS environment (SSD/NVMe first):\n'
for i in "${!disks[@]}"; do printf '  [%d] %s\n' "$((i + 1))" "${disks[$i]}"; done
read -r -p 'Select target disk number: ' choice
[[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#disks[@]}" ] || die "invalid disk selection"
disk="${disks[$((choice - 1))]%%$'\t'*}"

read -r -p 'Hostname [end4]: ' hostname; hostname="${hostname:-end4}"
read -r -p 'Primary username [end4]: ' username; username="${username:-end4}"
games=false; development=false; video=false; virtualization=false; ollama=false
ask_bool 'Enable development tools?' && development=true
ask_bool 'Enable gaming (Steam)?' && games=true
ask_bool 'Enable video editing tools?' && video=true
ask_bool 'Enable local virtualization (Docker/libvirt)?' && virtualization=true
ask_bool 'Enable local Ollama?' && ollama=true

printf '\nWARNING: every partition and all data on %s will be permanently destroyed.\n' "$disk"
read -r -p "Type exactly 'WIPE $disk' to continue: " confirmation
[ "$confirmation" = "WIPE $disk" ] || die "confirmation did not match; nothing changed"

parted -s "$disk" mklabel gpt
parted -s "$disk" mkpart ESP fat32 1MiB 1025MiB
parted -s "$disk" set 1 esp on
parted -s "$disk" mkpart primary btrfs 1025MiB 100%
partprobe "$disk"
sleep 2
if [[ "$disk" =~ [0-9]$ ]]; then efi="${disk}p1"; root="${disk}p2"; else efi="${disk}1"; root="${disk}2"; fi
mkfs.fat -F 32 -n EFI "$efi"
mkfs.btrfs -f -L nixos "$root"
mount "$root" /mnt
mkdir -p /mnt/boot
mount "$efi" /mnt/boot

install -d /mnt/etc/nixos/end4
cp -a "$repo"/. /mnt/etc/nixos/end4/
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/end4/installer/hardware-configuration.nix
cat > /mnt/etc/nixos/end4/installer/features.nix <<EOF
{ hostname = "${hostname}"; username = "${username}"; features = {
  games = ${games}; development = ${development}; videoEditing = ${video};
  virtualization = ${virtualization}; ollama = ${ollama};
}; }
EOF
nixos-install --flake /mnt/etc/nixos/end4#portable
printf '\nInstallation complete. Set a password with: nixos-enter --root /mnt -c "passwd %s"\n' "$username"
