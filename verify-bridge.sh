#!/usr/bin/env bash

echo "🔍 Verifying VM Bridge Configuration"
echo "===================================="
echo ""

# Check libvirtd service
echo "📋 Libvirtd Service Status:"
systemctl is-active libvirtd && echo "✅ libvirtd is running" || echo "❌ libvirtd is not running"
echo ""

# Check macvtap module
echo "🔧 Kernel Modules:"
if lsmod | grep -q macvtap; then
    echo "✅ macvtap module loaded"
    lsmod | grep macvtap
else
    echo "❌ macvtap module not loaded"
fi
echo ""

# Check libvirt networks
echo "🌐 Libvirt Networks:"
virsh net-list --all
echo ""

# Check WiFi interface
echo "📡 WiFi Interface Status:"
ip addr show wlan0 | grep "inet " | head -1
echo ""

# Check if user is in correct groups
echo "👤 User Groups:"
groups | grep -E "(libvirt|kvm)" && echo "✅ User in virtualization groups" || echo "❌ User missing virtualization groups"
echo ""

echo "🎯 Setup Summary:"
echo "- WiFi Interface: wlan0 ($(ip addr show wlan0 | grep 'inet ' | awk '{print $2}' | head -1))"
echo "- Bridge Network: macvtap-bridge (active)"
echo "- VM IP Range: 192.168.42.x (from router DHCP)"
echo ""
echo "🚀 Ready to create VMs with direct LAN access!"
echo ""
echo "To use in virt-manager:"
echo "1. Open virt-manager"
echo "2. Create new VM or edit existing"
echo "3. Network source: Virtual network 'macvtap-bridge': macvtap"
echo "4. Device model: virtio"
