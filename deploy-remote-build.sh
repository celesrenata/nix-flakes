#!/bin/bash
# Deploy NixOS configuration via Remote Build (NO file transfer)
# Usage: ./deploy-remote-build.sh user@hostname esnixi|macland
# 
# This uses nix's built-in remote build capability - the remote host builds locally!

set -e

REMOTE_HOST="${1:-user@esxi-server}"
CONFIG_NAME="${2:-esnixi}"

echo "🚀 Deploying NixOS configuration to $REMOTE_HOST..."
echo "   Configuration: #$CONFIG_NAME"
echo ""
echo "⚡ This method will NOT transfer any files - remote host builds locally!"
echo ""

# Step 1: Ensure SSH access is configured for nix build workers
echo "🔐 Verifying SSH access to $REMOTE_HOST..."
if ! ssh -o BatchMode=yes "$REMOTE_HOST" exit 0; then
    echo "❌ SSH connection failed. Please configure SSH key authentication first."
    echo ""
    echo "To set up SSH keys:"
    echo "  ssh-copy-id $REMOTE_HOST"
    echo ""
    exit 1
fi

# Step 2: Deploy using remote build
echo "🔧 Deploying configuration..."
sudo nixos-rebuild switch \
    --host "$REMOTE_HOST" \
    --flake "/home/celes/sources/nix-flakes-experimental\#$CONFIG_NAME" \
    --option build-use-sandbox true

# Step 3: Verify deployment
echo ""
echo "📊 Verifying deployment..."
ssh -o BatchMode=yes "$REMOTE_HOST" << EOF
    echo "=== System Status ==="
    systemctl status nix-daemon --no-pager | tail -5
    
    echo ""
    echo "=== GPU Status (NVIDIA) ==="
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
    else
        echo "NVIDIA drivers not detected or not configured"
    fi
    
    echo ""
    echo "=== Ollama Status ==="
    if systemctl is-active --quiet ollama; then
        echo "✅ Ollama service running"
        curl -s http://localhost:11434/api/tags | jq -r '.models[] | "\(.name) - \(.size/1024/1024/1024)GB"' 2>/dev/null || echo "No models loaded yet"
    else
        echo "Ollama service not running (may be disabled in configuration)"
    fi
    
    echo ""
    echo "=== Last NixOS Generation ==="
    nixos-rebuild list-generations | grep -E "^[-0-9]+|active"
EOF

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📚 Useful follow-up commands:"
echo "   ssh $REMOTE_HOST 'journalctl -u nix-daemon -f'     # Monitor build logs"
echo "   ssh $REMOTE_HOST 'sudo nixos-reboot'                # Reboot into new config"
