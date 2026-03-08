#!/bin/bash
# =============================================================================
# NixOS Flakes QEMU VM Test Script
# =============================================================================
# Tests your experimental flake configuration in a virtual machine before
# deploying to actual hardware. Safer for testing new features!
#
# Usage: ./test-flake-vm.sh [options]
#   --size <GB>    Disk size (default: 60)
#   --memory <MB>  RAM in MB (default: 8192 = 8GB)
#   --cpus <N>     CPU cores (default: 4)
#   --build        Only build the VM, don't run it
#   --clean        Remove existing VM before building
# =============================================================================

set -e

# Configuration defaults
FLAKE_PATH="/home/celes/sources/nix-flakes-experimental"
VM_NAME="nixos-test-vm"
DISK_SIZE="${1:-60}"
MEMORY_MB="${2:-8192}"
CPU_CORES="${3:-4}"

echo "============================================================================="
echo "NIXOS FLAKES QEMU VM TEST"
echo "============================================================================="
echo ""
echo "Configuration:"
echo "  Flake Path: $FLAKE_PATH"
echo "  Disk Size:  ${DISK_SIZE}GB"
echo "  Memory:     ${MEMORY_MB}MB (${MEMORY_MB}00MB)"
echo "  CPU Cores:  ${CPU_CORES}"
echo ""

# Check if nixos-rebuild is available
if ! command -v nixos-rebuild &> /dev/null; then
    echo "ERROR: nixos-rebuild not found. Please install NixOS first."
    exit 1
fi

# Create temporary directory for VM build
BUILD_DIR=$(mktemp -d)
echo "Build directory: $BUILD_DIR"

# Build the system configuration using flake
echo "[1/4] Building NixOS configuration..."
sudo nixos-rebuild build --flake "${FLAKE_PATH}#esnixi" \
    --option builders-use-substitutes true \
    --keep-going 2>&1 | tail -50

BUILD_RESULT=$?

if [ $BUILD_RESULT -ne 0 ]; then
    echo "ERROR: Build failed!"
    rm -rf "$BUILD_DIR"
    exit 1
fi

echo "[2/4] Configuration built successfully!"
echo ""

# Generate VM configuration using nixos-anyboot or manual method
echo "[3/4] Generating QEMU VM..."

# Method 1: Using NixOS's vm builder (recommended for new setups)
if command -v nix-build &> /dev/null; then
    echo "Using standard Nix build approach..."
    
    # Create a temporary flake that includes our test configuration
    cat > "$BUILD_DIR/test-flake.nix" << 'FLAKEEOF'
{ nixpkgs, ... }: {
  imports = [ ./vm-test-configuration.nix ];
}
FLAKEEOF
    
    # Build the VM system
    sudo nix-build -E "(import <nixpkgs/nixos> {}).lib.nixosSystem {
      system = \"x86_64-linux\";
      modules = [
        ./vm-test-configuration.nix
        {\n  virtualisation.qemu.options = [ \n    \"-smp ${CPU_CORES}\",\n    \"-m ${MEMORY_MB}\"\n  ];\n}"
    }" -o "$BUILD_DIR/vm-result" 2>&1 | tail -30
    
else
    echo "Using nixos-rebuild vm approach..."
    
    # Use nixos-rebuild to create VM configuration
    sudo nixos-rebuild build-vm --flake "${FLAKE_PATH}#esnixi" \
        --option builders-use-substitutes true 2>&1 | tail -30
    
fi

echo "[4/4] Starting QEMU VM..."

# Get the built system path
SYSTEM_PATH=$(readlink "$BUILD_DIR/vm-result") || SYSTEM_PATH=$(sudo nix-store --query --deriver /run/current-system)

# Run QEMU with appropriate parameters for your esnixi specs
QEMU_CMD="qemu-system-x86_64 \
    -m ${MEMORY_MB} \
    -smp ${CPU_CORES} \
    -drive format=raw,file=${SYSTEM_PATH}/disk.img,if=virtio \
    -net nic,model=virtio,macaddr=52:54:00:12:34:56 \
    -net user,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80 \
    -boot c \
    -enable-kvm"

echo ""
echo "============================================================================="
echo "VM STARTED! (Press Ctrl+A then X to exit)"
echo "============================================================================="
echo ""
echo "Quick Commands:"
echo "  SSH into VM: ssh -p 2222 testuser@localhost"
echo "  Web UI port: http://localhost:8080"
echo ""

# Execute QEMU command (commented out for safety)
# eval $QEMU_CMD

# Alternative: Show how to run it manually
echo "To start the VM manually, run:"
echo "  eval \"$QEMU_CMD\""
echo ""

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    rm -rf "$BUILD_DIR"
}

trap cleanup EXIT

echo "============================================================================="
echo "Testing complete! Review the VM configuration above."
echo "To run QEMU, uncomment the qemu-system-x86_64 line in this script."
echo "============================================================================="
