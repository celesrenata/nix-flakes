# NixOS VM Image Building Guide - Build Actual Disk Images!

## 🎯 Quick Start Commands

### 1. Local QEMU Testing (Quickest)
```bash
# Build a bootable VM image with your flake configuration
sudo nixos-rebuild build-vm --flake .\#esnixi

# Output:
# - ./result/bin/run-esnixi-vm    (script to launch the VM)
# - esnixi.qcow2                  (the actual disk image file)

# Launch the VM locally
./result/bin/run-esnixi-vm --enable-kvm
```

### 2. Build for Proxmox VE
```bash
# Install nixos-generators (if not already available in your NixOS version)
nix-env -f '<nixpkgs>' -iA nixos-generators

# Generate Proxmox-compatible image (.vma.zst format)
nixos-generate \
  --format proxmox \
  --config ./esnixi/configuration.nix \
  --disk-size 50G

# Output: esnixi-prox.maa.zst (ready to import into Proxmox!)
```

### 3. Build for ESXi / VMware
```bash
# Generate VMware-compatible image (.vmdk format)
nixos-generate \
  --format vmware \
  --config ./esnixi/configuration.nix \
  --disk-size 50G

# Output: esnixi-vmware.vmdk (ready to deploy on ESXi!)
```

### 4. Build Raw Image for KVM/QEMU
```bash
# Generate raw disk image (.raw format)
nixos-generate \
  --format qcow \
  --config ./esnixi/configuration.nix \
  --disk-size 50G

# Output: esnixi.qcow2 (QEMU/KVM compatible)
```

---

## 📊 Supported Image Formats (via nixos-generators)

| Format | File Extension | Target Platform | Best For |
|--------|---------------|-----------------|----------|
| `proxmox` | `.vma.zst` | Proxmox VE | Easy import, compression |
| `vmware` | `.vmdk` | VMware ESXi | Enterprise virtualization |
| `qcow` | `.qcow2` | QEMU/KVM | Local testing, libvirt |
| `raw` | `.raw` | Any hypervisor | Maximum compatibility |
| `ami` | `.img` | AWS EC2 | Cloud deployment |
| `gce` | `.tar.gz` | Google Cloud Platform | Cloud deployment |
| `hyper-v` | `.vhdx` | Microsoft Hyper-V | Windows environments |

---

## 🔧 Creating a Flake Output for VM Images (Recommended)

Add this to your `flake.nix`:

```nix
{
  description = "NixOS flake with VM image support";
  
  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      
      # Import nixos-generators as a flakes input (optional but recommended)
      generators = import (nixpkgs + "/nixos/generators");
      
      # Build VM image for Proxmox
      vm-proxmox = nixpkgs.lib.genAttrs [ "esnixi" "macland" ] (name:
        nixos-generators.prox {
          inherit name;
          modules = [ ./configuration.nix ];
          diskSize = 50 * 1024; # 50GB in MB
        } // {
          name = "vm-${name}-proxmox";
        });
      
      # Build VM image for ESXi/VMware
      vm-vmware = nixpkgs.lib.genAttrs [ "esnixi" "macland" ] (name:
        generators.vmware.default {
          inherit name;
          modules = [ ./configuration.nix ];
          diskSize = 50 * 1024; # 50GB in MB
        } // {
          name = "vm-${name}-vmware";
        });
    in
    {
      nixosConfigurations = {
        esnixi = nixpkgs.lib.nixosSystem {
          system = system;
          modules = [ ./configuration.nix ];
        };
        macland = nixpkgs.lib.nixosSystem {
          system = system;
          modules = [ ./configuration.nix ];
        };
      };
      
      packages.${system} = vm-proxmox // vm-vmware;
    };
}

# Then build with:
nix build .\#packages.x86_64-linux.vm-esnixi-proxmox
```

---

## 🚀 Deploying Built VM Images

### To Proxmox:
```bash
# Upload and import the image
qm import vm-id esnixi-prox.maa.zst -format vma
# OR for local testing, just copy to /var/lib/vz/images/
cp esnixi-prox.maa.zst /root/images/
```

### To ESXi:
```bash
# Upload the VMDK via SCP or datastore browser
scp esnixi-vmware.vmdk root@esxi-host:/vmfs/volumes/datastore1/images/

# Create VM and attach the disk via vSphere Client or CLI
vim-cd vm.create ...
```

### To Local QEMU:
```bash
qemu-system-x86_64 \
  -m 4096 \
  -cpu host \
  -enable-kvm \
  -drive file=esnixi.qcow2,format=qcow2 \
  -boot c \
  -netdev user,id=net0 \
  -device virtio-net-pci,netdev=net0
```

---

## 📝 Complete Example: VM Testing Script

Create `scripts/build-vm-image.sh`:

```bash
#!/bin/bash
# Build a NixOS VM image for testing

set -e

CONFIG_NAME="${1:-esnixi}"
FORMAT="${2:-qcow}"  # qcow, proxmox, vmware, raw, etc.
DISK_SIZE="${3:-50G}"

echo "Building $CONFIG_NAME VM image in $FORMAT format..."

cd /home/celes/sources/nix-flakes-experimental

# Build using nixos-generators
nixos-generate \
  --format "$FORMAT" \
  --config "./$CONFIG_NAME/configuration.nix" \
  --disk-size "${DISK_SIZE}" \
  --output "/tmp/$CONFIG_NAME.$FORMAT"

echo "✅ VM image built successfully!"
echo "   Location: /tmp/$CONFIG_NAME.$FORMAT"
echo ""
echo "To launch locally:"
if [ "$FORMAT" = "qcow" ]; then
    echo "  qemu-system-x86_64 -m 4096 -enable-kvm \\"
    echo "    -drive file=/tmp/$CONFIG_NAME.qcow2,format=qcow2"
elif [ "$FORMAT" = "proxmox" ]; then
    echo "  qm import <vm-id> /tmp/$CONFIG_NAME.vma.zst -format vma"
fi
```

Make it executable:
```bash
chmod +x scripts/build-vm-image.sh
./scripts/build-vm-image.sh esnixi proxmox 100G
```

---

## 🔄 CI/CD Integration Example (GitHub Actions)

Add to `.github/workflows/build-vm.yml`:

```yaml
name: Build VM Images

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-vms:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@main
        
      - name: Build Proxmox VM image
        run: |
          nixos-generate \
            --format proxmox \
            --config ./esnixi/configuration.nix \
            --disk-size 50G \
            --output esnixi-prox.vma.zst
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: vm-image-esnixi-proxmox
          path: esnixi-prox.vma.zst
```

---

## 🎯 Recommended Workflow for Your Project

### For Testing (Local QEMU)
```bash
# Quick test build
sudo nixos-rebuild build-vm --flake .\#esnixi
./result/bin/run-esnixi-vm --enable-kvm
```

### For Production Deployment (ESXi/Proxmox)
```bash
# Build portable image
nixos-generate \
  --format proxmox \
  --config ./esnixi/configuration.nix \
  --disk-size 50G

# Upload to your hypervisor
scp esnixi-prox.vma.zst user@your-hypervisor:/images/
```

### For CI/CD Pipeline
Add `nixos-generators` flake input and build images automatically on push.

---

## 📚 Key Resources

| Resource | Purpose |
|----------|---------|
| [NixOS Generators](https://github.com/nix-community/nixos-generators) | Build VM images for multiple platforms |
| [nixos-rebuild build-vm docs](https://wiki.nixos.org/wiki/NixOS%3Anixos-rebuild_build-vm) | Local QEMU testing |
| [NixOS Manual - Images](https://nixos.org/manual/nixos/stable/) | Cloud/hypervisor-specific images |

---

## ✅ Summary

**You were absolutely right!** NixOS has excellent built-in tools for building actual VM disk images:

1. **`nixos-rebuild build-vm`** - Quick local testing (creates `.qcow2`)
2. **`nixos-generators`** - Multi-platform support (Proxmox, ESXi, etc.)
3. **`system.build.vm`** - Flake-based VM builds

No XML files needed! Just pure Nix configuration and the appropriate build command. 🎉
