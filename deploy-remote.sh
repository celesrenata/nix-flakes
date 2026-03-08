#!/bin/bash
# Deploy NixOS configuration to remote host WITHOUT copying build results
# Usage: ./deploy-remote.sh user@hostname esnixi|macland

set -e

REMOTE_HOST="${1:-user@esxi-server}"
CONFIG_NAME="${2:-esnixi}"
LOCAL_DIR="/home/celes/sources/nix-flakes-experimental"

echo "🚀 Deploying NixOS configuration to $REMOTE_HOST..."
echo "   Configuration: #$CONFIG_NAME"
echo ""

# Step 1: Create clean tarball (excluding build artifacts)
echo "📦 Creating clean source archive..."
cd "$LOCAL_DIR"
tar --exclude='result' \
    --exclude='.nix-output-monitor' \
    --exclude='*.lock' \
    --exclude='**/*.tar.gz' \
    --exclude='**/*.tar.xz' \
    -czf /tmp/nixos-config-$CONFIG_NAME.tar.gz \
    flake.nix feature-flags.nix configuration.nix esnixi/ macland/ overlays/ home/ modules/ scripts/

# Step 2: Transfer to remote host
echo "📡 Transferring to $REMOTE_HOST..."
scp /tmp/nixos-config-$CONFIG_NAME.tar.gz "$REMOTE_HOST:/tmp/"

# Step 3: Deploy on remote host
echo "🔧 Deploying configuration on remote host..."
ssh "$REMOTE_HOST" << 'EOF'
    cd /tmp
    tar -xzf nixos-config-esnixi.tar.gz
    sudo nixos-rebuild switch --flake .\#esnixi
    rm -f nixos-config-esnixi.tar.gz
EOF

# Cleanup local temp file
rm -f /tmp/nixos-config-$CONFIG_NAME.tar.gz

echo ""
echo "✅ Deployment complete! Check remote host for status."
echo "   To verify: ssh $REMOTE_HOST 'systemctl status nix-daemon'"
