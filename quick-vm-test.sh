#!/bin/bash
# =============================================================================
# Quick VM Test - One Command Testing for NixOS Flakes
# =============================================================================
# Tests your experimental flake in a QEMU VM before deploying to hardware!
# Perfect for esnixi server with good specs (RAM, CPU, disk space)
#
# Usage: ./quick-vm-test.sh [options]
#   --build-only      Only build the VM configuration, don't run it
#   --run             Build AND run the VM immediately
#   --dry-run         Show what would be done without executing
# =============================================================================

set -e

FLAKE_PATH="/home/celes/sources/nix-flakes-experimental"
SYSTEM_NAME="esnixi"

echo "============================================================================="
echo "QUICK VM TEST FOR NIXOS FLAKES"
echo "============================================================================="
echo ""
echo "Testing: $FLAKE_PATH#$SYSTEM_NAME"
echo ""

# Parse arguments
BUILD_ONLY=false
RUN_VM=false
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --build-only) BUILD_ONLY=true ;;
        --run) RUN_VM=true ;;
        --dry-run) DRY_RUN=true ;;
    esac
done

# Check dependencies
echo "[1/5] Checking system requirements..."
if ! command -v nixos-rebuild &> /dev/null; then
    echo "ERROR: nixos-rebuild not found. Please install NixOS first."
    exit 1
fi

if ! command -v qemu-system-x86_64 &> /dev/null && [ "$RUN_VM" = true ]; then
    echo "WARNING: QEMU not installed. Will only build the VM config."
    RUN_VM=false
fi

echo "[2/5] Checking flake syntax..."
nix flake check "$FLAKE_PATH" >/dev/null 2>&1 || {
    echo "ERROR: Flake has syntax errors!"
    nix flake check "$FLAKE_PATH"
    exit 1
}
echo "✓ Flake syntax valid"

echo "[3/5] Building NixOS configuration..."
if [ "$DRY_RUN" = true ]; then
    sudo nixos-rebuild build --flake "${FLAKE_PATH}#${SYSTEM_NAME}" \
        --option builders-use-substitutes true \
        --dry-run 2>&1 | tail -30
else
    sudo nixos-rebuild build --flake "${FLAKE_PATH}#${SYSTEM_NAME}" \
        --option builders-use-substitutes true \
        --keep-going 2>&1 | tail -50
fi

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    echo ""
    echo "ERROR: Build failed!"
    exit 1
fi

echo "[4/5] Configuration built successfully!"
echo "   System path: /nix/store/results/*-esnixi"

# Show build result
ls -la /nix/store/*.nixos-system-* | grep esnixi || true

echo ""
if [ "$RUN_VM" = true ]; then
    echo "[5/5] Preparing QEMU VM launch..."
    
    # Find the built system
    SYSTEM_PATH=$(find /nix/store -maxdepth 1 -name "*esnixi*" -type d | head -1)
    
    if [ -z "$SYSTEM_PATH" ]; then
        echo "ERROR: Could not find built system!"
        exit 1
    fi
    
    # Create VM disk image
    DISK_IMG="$HOME/nixos-test-disk.img"
    if [ ! -f "$DISK_IMG" ]; then
        echo "Creating 60GB VM disk image..."
        qemu-img create -f qcow2 "$DISK_IMG" 60G
    fi
    
    # QEMU launch command
    cat > ~/launch-vm.sh << EOFQEMU
#!/bin/bash
echo "Starting NixOS VM Test (press Ctrl+A then X to exit)..."
qemu-system-x86_64 \\
    -m 8192 \\
    -smp 4 \\
    -drive file=$DISK_IMG,format=qcow2,if=virtio \\
    -boot c \\
    -enable-kvm \\
    -net nic,model=virtio,macaddr=52:54:00:12:34:56 \\
    -net user,hostfwd=tcp::2222-:22 \\
    -serial stdio

echo "VM stopped"
EOFQEMU
    
    chmod +x ~/launch-vm.sh
    
    echo ""
    echo "============================================================================="
    echo "VM READY TO RUN!"
    echo "============================================================================="
    echo ""
    echo "To start the VM, run:"
    echo "  ./~/launch-vm.sh"
    echo ""
    echo "Quick Commands in QEMU:"
    echo "  Ctrl+A then X - Exit (don't just quit!)"
    echo ""
    echo "After boot, SSH into VM:"
    echo "  ssh -p 2222 testuser@localhost"
    echo ""
    
else
    echo "[5/5] Build complete. To run in QEMU manually:"
    echo ""
    echo "1. Create disk image: qemu-img create -f qcow2 ~/vm-disk.img 60G"
    echo "2. Run QEMU:"
    echo "   qemu-system-x86_64 \\
       -m 8192 -smp 4 \\
       -drive file=~/nixos-test-disk.img,format=qcow2,if=virtio \\
       -boot c -enable-kvm \\
       -net nic,model=virtio -net user,hostfwd=tcp::2222-:22"
    echo ""
fi

echo "============================================================================="
echo "Testing complete!"
echo "============================================================================="
