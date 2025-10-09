#!/usr/bin/env bash

set -e

echo "Setting up VM bridge for direct LAN access..."

# Check if libvirtd is running
if ! systemctl is-active --quiet libvirtd; then
    echo "Starting libvirtd service..."
    sudo systemctl start libvirtd
    sudo systemctl enable libvirtd
fi

# Load macvtap module
echo "Loading macvtap kernel module..."
sudo modprobe macvtap

# Create the macvtap network
echo "Creating macvtap network for direct LAN access..."
if virsh net-list --all | grep -q "macvtap-bridge"; then
    echo "Network already exists, destroying and recreating..."
    virsh net-destroy macvtap-bridge 2>/dev/null || true
    virsh net-undefine macvtap-bridge 2>/dev/null || true
fi

# Define and start the network
virsh net-define macvtap-network.xml
virsh net-start macvtap-bridge
virsh net-autostart macvtap-bridge

echo ""
echo "✅ Bridge setup complete!"
echo ""
echo "Your VMs will now get direct IP addresses from your router (192.168.42.x range)"
echo ""
echo "To use this in virt-manager:"
echo "1. Open virt-manager"
echo "2. Create a new VM or edit existing VM"
echo "3. In Network settings, select:"
echo "   - Network source: Virtual network 'macvtap-bridge': macvtap"
echo "   - Device model: virtio"
echo ""
echo "The VM will receive a direct IP from your router's DHCP server."

# Show current network status
echo ""
echo "Current libvirt networks:"
virsh net-list --all
