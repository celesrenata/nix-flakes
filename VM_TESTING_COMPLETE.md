# NixOS Flakes VM Testing - Complete Setup Guide

## ✅ What You Have Now

Your experimental flake configuration includes **safe QEMU VM testing capabilities** for esnixi before deploying to your MacBook T2!

### 🎯 Quick Start Commands

```bash
cd ~/sources/nix-flakes-experimental

# Test 1: Check if configuration is valid
./quick-vm-test.sh --dry-run

# Test 2: Build VM configuration (no QEMU)
sudo nixos-rebuild build --flake .#esnixi --dry-run

# Test 3: Interactive testing menu
./test-vm-methods.sh
```

### 📁 Files Created for Testing

| File | Purpose | Status |
|------|---------|--------|
| `quick-vm-test.sh` | One-command VM test | ✅ Ready to use |
| `test-vm-methods.sh` | Interactive testing menu | ✅ Ready to use |
| `select-gpu-kernel.sh` | Switch GPU/kernel configs | ✅ Working |
| `VM_TESTING_GUIDE.md` | Complete documentation | ✅ Available |

### 🚀 How to Test Your Flakes in QEMU VM

#### Method 1: Quick Test (Recommended)
```bash
# Just check if configuration builds
./quick-vm-test.sh --dry-run

# Build WITHOUT running QEMU
sudo nixos-rebuild build --flake ~/sources/nix-flakes-experimental#esnixi \
    --option builders-use-substitutes true
```

#### Method 2: Full VM Test (Build + Run)
```bash
# This will create and launch a QEMU VM with your config
./quick-vm-test.sh --run

# After it starts, press Ctrl+A then X to exit QEMU
# SSH into VM from host: ssh -p 2222 testuser@localhost
```

#### Method 3: Interactive Testing
```bash
# Choose testing method interactively
./test-vm-methods.sh

# Options:
#   1. Standard nix-build (most reliable)
#   2. Manual QEMU configuration  
#   3. NixOS vm builder script
```

### 🎮 GPU & Kernel Selection Testing

Before testing, choose your GPU/kernel combination:

```bash
# Test with NVIDIA + Linux 6.19 (your original setup)
./select-gpu-kernel.sh nvidia 6_19

# Test with AMD ROCm + Linux 6.12  
./select-gpu-kernel.sh rocm 6_12

# Then rebuild the VM configuration:
sudo nixos-rebuild build --flake .#esnixi --dry-run
```

### 🛡️ Safety Features

#### Rollback Plan (Always Available)
```bash
# From host machine if VM fails to boot:
sudo nixos-rebuild switch -r 1  # Revert to previous generation

# Or from within QEMU console:
sudo nixos-rebuild switch -r 1
```

#### Disk Cleanup After Testing
```bash
# Remove test artifacts when done:
rm ~/nixos-test-disk.img
rm ~/launch-vm.sh
```

### 📊 VM Specifications (Default)

| Parameter | Value | Can Be Adjusted |
|-----------|-------|-----------------|
| Memory | 8192 MB (8GB) | Yes - increase if esnixi has more RAM |
| CPU Cores | 4 | Yes - use more for faster builds |
| Disk Size | 60 GB | Yes - increase for larger VMs |
| Network | NAT + SSH forwarding | Port 2222 → VM:22 |

### 🔍 Testing Workflow

```bash
# Step 1: Validate configuration syntax
nix flake check ~/sources/nix-flakes-experimental

# Step 2: Dry-run build (no changes)
sudo nixos-rebuild build --flake .#esnixi --dry-run

# Step 3: Full VM test in QEMU
./quick-vm-test.sh --run

# Step 4: Test features inside VM via SSH:
ssh -p 2222 testuser@localhost
password: test123

# Step 5: If successful, deploy to hardware!
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi
```

### 🐛 Troubleshooting Common Issues

| Issue | Solution |
|-------|----------|
| **QEMU not installed** | `sudo apt install qemu-system-x86` or use nix-env |
| **KVM not available** | Enable virtualization in BIOS, check CPU support |
| **SSH won't connect** | Check firewall: `sudo ufw allow 2222/tcp` |
| **Build fails** | Run with `--show-trace` for detailed errors |

### 🎯 Next Steps

1. **Review the configuration** - Make sure it matches your needs
2. **Test in QEMU VM first** - Never deploy directly to hardware!
3. **Validate GPU/kernel selection** - Use select-gpu-kernel.sh
4. **After successful VM test**, deploy to esnixi server
5. **Keep rollback plan ready** - Always know how to revert

---

## 📞 Documentation Files

- `VM_TESTING_GUIDE.md` - Complete testing guide with examples
- `quick-vm-test.sh` - One-command VM testing (executable)
- `test-vm-methods.sh` - Interactive menu for testing methods
- `select-gpu-kernel.sh` - GPU/kernel selection helper

---

**You're ready to safely test your NixOS flake configuration in a QEMU VM!** 🚀

Test thoroughly, then deploy with confidence!
