#!/usr/bin/env bash
# Reset Hyprland configuration while preserving custom.conf

set -e

echo "🔄 Resetting Hyprland configuration..."

# Backup custom.conf if it exists
if [ -f ~/.config/hypr/custom.conf ]; then
    echo "📦 Backing up custom.conf..."
    cp ~/.config/hypr/custom.conf /tmp/hypr-custom.conf.backup
fi

# Remove initialization marker
if [ -f ~/.local/share/initialSetup ]; then
    echo "🗑️  Removing initialization marker..."
    rm ~/.local/share/initialSetup
fi

# Remove mutable config directories (keep symlinks from nix)
echo "🗑️  Removing mutable config directories..."
rm -rf ~/.config/quickshell/ii
rm -rf ~/.config/hypr/hyprland

# Restore custom.conf
if [ -f /tmp/hypr-custom.conf.backup ]; then
    echo "📥 Restoring custom.conf..."
    mkdir -p ~/.config/hypr
    cp /tmp/hypr-custom.conf.backup ~/.config/hypr/custom.conf
    rm /tmp/hypr-custom.conf.backup
fi

echo "✅ Configuration reset complete!"
echo "ℹ️  Run 'initialSetup.sh' or reboot to reinitialize"
