#!/bin/bash
# Build NixOS VM images from flake configuration
# Usage: ./build-vm-image.sh <config-name> <format> [disk-size]

set -e

CONFIG_NAME="${1:-esnixi}"
FORMAT="${2:-qcow}"  # qcow, proxmox, vmware, raw, etc.
DISK_SIZE="${3:-50G}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Building NixOS VM image for: $CONFIG_NAME"
echo "   Format: $FORMAT"
echo "   Disk Size: $DISK_SIZE"
echo ""

cd "$SCRIPT_DIR"

# Check if nixos-generators is available
if ! command -v nixos-generate &> /dev/null; then
    echo "⚠️  Installing nixos-generators..."
    nix-env -f '<nixpkgs>' -iA nixos-generators
fi

# Build the VM image
OUTPUT_FILE="/tmp/nixos-vm-${CONFIG_NAME}.${FORMAT}"

echo "📦 Building image..."
nixos-generate \
  --format "$FORMAT" \
  --config "./${CONFIG_NAME}/configuration.nix" \
  --disk-size "${DISK_SIZE}" \
  --output "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "✅ VM image built successfully!"
    echo "   Location: $OUTPUT_FILE"
    echo "   Size: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo ""
    
    case "$FORMAT" in
        qcow|raw)
            echo "🚀 To launch locally with QEMU:"
            echo "  qemu-system-x86_64 \\"
            echo "    -m 4096 \\"
            echo "    -cpu host \\"
            echo "    -enable-kvm \\"
            echo "    -drive file=$OUTPUT_FILE,format=$( [ "$FORMAT" = "qcow" ] && echo qcow2 || echo raw ) \\"
            echo "    -boot c \\"
            echo "    -netdev user,id=net0 \\"
            echo "    -device virtio-net-pci,netdev=net0"
            ;;
        proxmox)
            echo "🚀 To import into Proxmox:"
            echo "  qm import <vm-id> $OUTPUT_FILE -format vma"
            echo ""
            echo "   Or copy to /var/lib/vz/images/ and import via web UI"
            ;;
        vmware)
            echo "🚀 To deploy on ESXi:"
            echo "  scp $OUTPUT_FILE root@esxi-host:/vmfs/volumes/datastore1/images/"
            echo ""
            echo "   Then attach to VM via vSphere Client or CLI"
            ;;
        *)
            echo "ℹ️  Output format: $FORMAT"
            echo "   See nixos-generators documentation for deployment instructions"
            ;;
    esac
    
    echo ""
    echo "📁 File details:"
    ls -lh "$OUTPUT_FILE"
else
    echo "❌ Build failed!"
    exit 1
fi
