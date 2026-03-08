#!/bin/bash
# =============================================================================
# NixOS Flakes VM Test - Multiple Testing Methods
# =============================================================================
# Choose from several methods to test your flake configuration in a QEMU VM
# before deploying to actual hardware!
#
# Methods:
#   1. Standard nix-build (most reliable)
#   2. nixos-anyboot (experimental, requires setup)
#   3. Manual QEMU build (full control)
# =============================================================================

set -e

FLAKE_PATH="/home/celes/sources/nix-flakes-experimental"
SYSTEM_NAME="esnixi"

echo "============================================================================="
echo "NIXOS FLAKES VM TESTING OPTIONS"
echo "============================================================================="
echo ""
echo "Choose a testing method:"
echo "  Method 1: Standard nix-build (recommended)"
echo "  Method 2: Manual QEMU configuration"
echo "  Method 3: NixOS vm builder script"
echo ""
read -p "Enter choice [1-3]: " METHOD

case $METHOD in
    1) method_standard ;;
    2) method_manual_qemu ;;
    3) method_nixos_vm ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

# =============================================================================
# Method 1: Standard nix-build approach (most reliable)
# =============================================================================
method_standard() {
    echo ""
    echo "=== METHOD 1: STANDARD NIX-BUILD ==="
    echo ""
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    echo "[1/5] Creating test flake..."
    cat > flake.nix << 'EOF'
{
  description = "NixOS VM Test Configuration";
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    your-flake.url = file:///home/celes/sources/nix-flakes-experimental;
  };
  
  outputs = { self, nixpkgs, your-flake }: {
    nixosConfigurations.testvm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./test-configuration.nix
        ${your-flake}/nixosModules.testvm  # Add your flake's test module if available
      ];
    };
  };
}
EOF

    cat > test-configuration.nix << 'EOF'
{ config, pkgs, lib, ... }: {
  imports = [
    ${your-flake}/configuration.nix
    ${your-flake}/esnixi/boot.nix
    ${your-flake}/esnixi/graphics.nix
    ${your-flake}/esnixi/networking.nix
  ];

  # VM-specific settings
  boot.loader.grub.enable = true;
  consoleLogLevel = 0;
  
  users.users.testuser = {
    isNormalUser = true;
    description = "VM Test User";
    extraGroups = [ "wheel" ];
    initialPassword = "test123";
  };

  environment.systemPackages = with pkgs; [ vim git htop ];
}
EOF
    
    echo "[2/5] Building NixOS configuration..."
    sudo nix-build -E "(import <nixpkgs/nixos> {}).lib.nixosSystem { system = \"x86_64-linux\"; modules = [ ./test-configuration.nix ]; }" \
        --option builders-use-substitutes true 2>&1 | tail -20
    
    echo "[3/5] Build complete!"
    echo "VM configuration created at: $TEMP_DIR/result"
    echo ""
    
    # Cleanup temp directory
    cd /home/celes/sources/nix-flakes-experimental
    rm -rf "$TEMP_DIR"
}

# =============================================================================
# Method 2: Manual QEMU Configuration (full control)
# =============================================================================
method_manual_qemu() {
    echo ""
    echo "=== METHOD 2: MANUAL QEMU CONFIGURATION ==="
    echo ""
    
    # Build the system first
    echo "[1/4] Building NixOS system..."
    sudo nixos-rebuild build --flake "${FLAKE_PATH}#${SYSTEM_NAME}" \
        --option builders-use-substitutes true 2>&1 | tail -30
    
    BUILD_RESULT=$?
    
    if [ $BUILD_RESULT -ne 0 ]; then
        echo "ERROR: Build failed!"
        exit 1
    fi
    
    echo "[2/4] System built successfully!"
    
    # Create QEMU launch script
    cat > ~/run-vm-test.sh << 'EOF'
#!/bin/bash
# Manual QEMU VM Test Script

SYSTEM_PATH="/nix/store/hdq2511x7cn33rg6a44ws9qcz010jm5n-nixos-system-esnixi-25.11.20260302.c581273"
DISK_SIZE="60G"
CPU_CORES=4
MEMORY_MB=8192

# Create disk image if it doesn't exist
if [ ! -f ~/vm-disk.img ]; then
    echo "Creating 60GB VM disk image..."
    qemu-img create -f qcow2 ~/vm-disk.img $DISK_SIZE
fi

# Launch QEMU with your system
echo "Starting QEMU VM (press Ctrl+A then X to exit)..."
qemu-system-x86_64 \
    -m ${MEMORY_MB} \
    -smp ${CPU_CORES} \
    -drive file=~/vm-disk.img,format=qcow2,if=virtio \
    -boot c \
    -enable-kvm \
    -net nic,model=virtio,macaddr=52:54:00:12:34:56 \
    -net user,hostfwd=tcp::2222-:22 \
    -serial stdio

echo "VM stopped"
EOF
    
    chmod +x ~/run-vm-test.sh
    
    echo "[3/4] VM test script created at: ~/run-vm-test.sh"
    
    # Show how to use it
    cat << 'USAGE'
=============================================================================
MANUAL QEMU TESTING INSTRUCTIONS
=============================================================================

To run the VM, execute:
  ./~/run-vm-test.sh

Or customize parameters first:
  nano ~/run-vm-test.sh

Key Commands in QEMU:
  Ctrl+A then X - Exit QEMU (don't just quit!)
  
SSH into running VM (after boot):
  ssh -p 2222 testuser@localhost
  
=============================================================================
USAGE
    
    echo ""
    echo "[4/4] Ready to test!"
}

# =============================================================================
# Method 3: NixOS vm builder script (if available)
# =============================================================================
method_nixos_vm() {
    echo ""
    echo "=== METHOD 3: NIXOS VM BUILDER ==="
    echo ""
    
    # Check if nixos-anyboot is available
    if command -v nixos-anyboot &> /dev/null; then
        echo "nixos-anyboot found, using it for testing..."
        sudo nixos-anyboot --flake "${FLAKE_PATH}#${SYSTEM_NAME}" \
            --cpus 4 \
            --memory 8192 \
            --disk-size 60G
    else
        echo "nixos-anyboot not installed. Installing now..."
        
        # Try to install nixos-anyboot from unstable channel
        sudo nix-env -iA nixpkgs.nixos-anyboot
        
        if [ $? -eq 0 ]; then
            echo "Installed successfully!"
            sudo nixos-anyboot --flake "${FLAKE_PATH}#${SYSTEM_NAME}" \
                --cpus 4 \
                --memory 8192 \
                --disk-size 60G
        else
            echo "ERROR: Could not install nixos-anyboot"
            echo "Using Method 2 (manual QEMU) instead..."
            method_manual_qemu
        fi
    fi
}

# =============================================================================
# Main execution
# =============================================================================
echo ""
echo "Starting VM test setup..."
echo ""

case $METHOD in
    1) 
        echo "Method 1: Standard nix-build - Creating temporary flake and building..."
        method_standard
        ;;
    2) 
        echo "Method 2: Manual QEMU - Full control over parameters..."
        method_manual_qemu
        ;;
    3) 
        echo "Method 3: NixOS VM Builder - Using nixos-anyboot..."
        method_nixos_vm
        ;;
esac

echo ""
echo "============================================================================="
echo "VM TESTING SETUP COMPLETE!"
echo ""
echo "Next steps:"
echo "1. Review the configuration files created"
echo "2. Run the VM using the instructions above"
echo "3. Test your flake features in a safe environment"
echo "4. If successful, deploy to actual hardware"
echo "============================================================================="
