#!/usr/bin/env bash

echo "🔍 Toshy Configuration Test Script"
echo "=================================="

# Test 1: Check if Toshy flake input is working
echo -e "\n1. Testing Toshy flake input..."
if nix flake show github:celesrenata/toshy 2>/dev/null | grep -q "packages"; then
    echo "✅ Toshy flake is accessible"
else
    echo "❌ Cannot access Toshy flake"
fi

# Test 2: Check flake configuration
echo -e "\n2. Testing flake configuration..."
if nix flake check --no-build 2>&1 | grep -q "checking NixOS configuration"; then
    echo "✅ Flake configuration is valid"
else
    echo "❌ Flake configuration has issues"
fi

# Test 3: Check if Toshy module is available
echo -e "\n3. Testing Toshy NixOS module..."
if nix eval .#nixosConfigurations.esnixi.config.services.toshy.enable 2>/dev/null | grep -q "true"; then
    echo "✅ Toshy service is enabled in configuration"
else
    echo "⚠️  Toshy service may not be enabled (this is normal before rebuild)"
fi

# Test 4: Check if user is in input group (after rebuild)
echo -e "\n4. Checking user permissions..."
if groups | grep -q "input"; then
    echo "✅ User is in input group"
else
    echo "⚠️  User not in input group (will be fixed after nixos-rebuild)"
fi

# Test 5: Check if Toshy processes are running (after rebuild)
echo -e "\n5. Checking Toshy services..."
if systemctl --user is-active toshy >/dev/null 2>&1; then
    echo "✅ Toshy daemon is running"
else
    echo "⚠️  Toshy daemon not running (normal before rebuild)"
fi

echo -e "\n📋 Next Steps:"
echo "1. Run: sudo nixos-rebuild switch"
echo "2. Log out and log back in (to apply group membership)"
echo "3. Check services: systemctl --user status toshy"
echo "4. Test keybindings: Try Cmd+T in Firefox"
echo "5. Debug if needed: toshy-debug"

echo -e "\n🔧 Useful Commands After Rebuild:"
echo "- toshy-platform    # Check platform info"
echo "- toshy-debug       # Run diagnostics"
echo "- toshy-config --info  # Check configuration"
echo "- systemctl --user status toshy  # Check service status"
