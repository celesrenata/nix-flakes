#!/bin/bash
# =============================================================================
# VM Testing Setup Script for esnixi Server
# =============================================================================
# Run this script on esnixi to prepare the testing environment
#
# Usage: ./setup-vm-testing.sh [options]
#   --run-tests    Run the automated tests immediately after setup
#   --help         Show help message
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_PATH="$SCRIPT_DIR"

echo "============================================================================="
echo "NIXOS FLAKES VM TESTING SETUP FOR ESXNI"
echo "============================================================================="
echo ""
echo "Flake Path: $FLAKE_PATH"
echo ""

# Check if files are present
echo "[1/5] Checking required files..."
REQUIRED_FILES=(
    "$FLAKE_PATH/quick-vm-test.sh"
    "$FLAKE_PATH/test-vm-methods.sh" 
    "$FLAKE_PATH/select-gpu-kernel.sh"
    "$FLAKE_PATH/vm-test-configuration.nix"
    "$FLAKE_PATH/esnixi/gpu-kernel-flags.nix"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Missing required file: $file"
        exit 1
    fi
done
echo "✓ All required files present"

# Make scripts executable
echo "[2/5] Making scripts executable..."
chmod +x "$FLAKE_PATH/quick-vm-test.sh" \
         "$FLAKE_PATH/test-vm-methods.sh" \
         "$FLAKE_PATH/select-gpu-kernel.sh"
echo "✓ Scripts are now executable"

# Check for required system tools
echo "[3/5] Checking system requirements..."
if ! command -v nixos-rebuild &> /dev/null; then
    echo "ERROR: nixos-rebuild not found. Please install NixOS first."
    exit 1
fi

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "WARNING: QEMU not installed. VM testing will be limited to build-only mode."
    echo "To install QEMU, run: sudo apt install qemu-system-x86"
else
    echo "✓ QEMU found and ready for VM testing"
fi

if ! command -v nix &> /dev/null; then
    echo "ERROR: Nix not installed. Please install Nix first."
    exit 1
fi
echo "✓ System requirements met"

# Show current configuration
echo "[4/5] Current GPU/kernel selection..."
cd "$FLAKE_PATH"
./select-gpu-kernel.sh show

echo ""
echo "[5/5] Setup complete!"
echo ""

# Optional: Run automated tests
if [ "${1:-}" = "--run-tests" ]; then
    echo "Running automated tests..."
    ./quick-vm-test.sh --dry-run
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ All tests passed! You can now run VM testing."
    else
        echo ""
        echo "⚠ Some tests failed. Review errors above before proceeding."
    fi
else
    echo "Setup complete. Run the following command to start testing:"
    echo ""
    echo "  ./quick-vm-test.sh --dry-run"
fi

echo ""
echo "============================================================================="
echo "NEXT STEPS FOR TESTING:"
echo "============================================================================="
echo ""
echo "1. Test configuration syntax (recommended first step):"
echo "   ./quick-vm-test.sh --dry-run"
echo ""
echo "2. Choose GPU/kernel combination before testing:"
echo "   ./select-gpu-kernel.sh nvidia 6_19    # NVIDIA + Linux 6.19"
echo "   ./select-gpu-kernel.sh rocm 6_12      # AMD ROCm + Linux 6.12"
echo ""
echo "3. Build VM configuration without running QEMU:"
echo "   sudo nixos-rebuild build --flake .#esnixi --dry-run"
echo ""
echo "4. Run full VM test (requires QEMU installed):"
echo "   ./quick-vm-test.sh --run"
echo ""
echo "5. After successful testing, deploy to hardware:"
echo "   sudo nixos-rebuild switch --flake .#esnixi"
echo ""
echo "For detailed instructions, see: VM_TESTING_COMPLETE.md"
echo "============================================================================="
