# NixOS Flakes VM Testing Guide

## Overview

This guide shows you how to safely test your experimental flake configuration in a QEMU virtual machine before deploying to actual hardware. Perfect for testing new features, kernel changes, or GPU configurations!

## 🎯 Quick Start (Recommended)

### One-Command Test
```bash
# Build and show VM launch instructions
./quick-vm-test.sh

# Or build AND run immediately
./quick-vm-test.sh --run
```

## 🔧 Testing Methods Available

| Method | Command | When to Use |
|--------|---------|-------------|
| **Quick Test** | `./quick-vm-test.sh` | Fastest - builds config only |
| **Run VM Now** | `./quick-vm-test.sh --run` | Build + launch QEMU immediately |
| **Choose Method** | `./test-vm-methods.sh` | Interactive menu with multiple options |

## 📋 Detailed Usage

### Quick Test (Build Only)
```bash
cd ~/sources/nix-flakes-experimental
./quick-vm-test.sh --dry-run  # Preview without executing
./quick-vm-test.sh            # Build configuration
```

**Output:** Creates VM launch script at `~/launch-vm.sh`

### Run VM Immediately
```bash
# Builds and launches QEMU automatically
./quick-vm-test.sh --run
```

**Output:** Starts QEMU VM with:
- 8GB RAM, 4 CPU cores
- 60GB virtual disk
- SSH forwarding on port 2222

### Interactive Menu
```bash
# Choose from multiple testing approaches
./test-vm-methods.sh
```

Options:
1. **Standard nix-build** - Most reliable method
2. **Manual QEMU** - Full control over parameters  
3. **NixOS VM Builder** - Uses `nixos-anyboot` if available

## 🚀 After VM Launch

### Quick Commands in QEMU Terminal
```bash
# Exit QEMU (IMPORTANT: don't just quit!)
Press Ctrl+A, then press X

# SSH into running VM (from your host)
ssh -p 2222 testuser@localhost
password: test123
```

### Testing Checklist in VM
- [ ] Boot completed successfully
- [ ] Network connectivity works
- [ ] SSH access functional
- [ ] Graphics display working (if applicable)
- [ ] All features from your flake work correctly
- [ ] No errors or warnings in logs

## 🛡️ Safety Features

### Rollback Plan
```bash
# From host machine, if VM fails to boot:
sudo nixos-rebuild switch -r 1  # Revert to previous generation

# Or from within QEMU (if you can access it):
sudo nixos-rebuild switch -r 1
```

### Disk Cleanup After Testing
```bash
# Remove test disk image when done
rm ~/nixos-test-disk.img
rm ~/launch-vm.sh
```

## 📊 VM Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Memory** | 8192 MB (8GB) | Adjust for your esnixi specs |
| **CPU Cores** | 4 | Can increase if esnixi has more |
| **Disk Size** | 60 GB | Sufficient for full system |
| **Network** | NAT + SSH forwarding | Port 2222 → VM:22 |
| **Graphics** | VirtIO (basic) | Not GPU-accelerated in test |

## 🔍 Debugging Tips

### Build Failed?
```bash
# See detailed error output
sudo nixos-rebuild build --flake ~/sources/nix-flakes-experimental#esnixi \
    --show-trace 2>&1 | less

# Check flake syntax
nix flake check ~/sources/nix-flakes-experimental

# Try with substitutions (faster)
sudo nixos-rebuild build --flake ... \
    --option builders-use-substitutes true
```

### VM Won't Boot?
```bash
# Check QEMU logs
qemu-system-x86_64 -m 8192 -smp 4 \
    -drive file=~/nixos-test-disk.img,format=qcow2 \
    -boot c -enable-kvm \
    -serial stdio

# Try with different boot options
qemu-system-x86_64 ... -boot order=c
```

### Network Issues in VM?
```bash
# Enable verbose network output in flake
networking.networkmanager.enable = true;
networking.useDHCP = true;
```

## 🌟 Best Practices

1. **Always test new features first** in VM before hardware deployment
2. **Use `--dry-run`** to preview what will happen without changes
3. **Keep rollback plan ready** - know how to revert quickly
4. **Test kernel changes** in VM (critical for stability!)
5. **Verify GPU configs** work correctly before production deploy

## 📝 Example Testing Workflow

```bash
# 1. Quick validation
nix flake check ~/sources/nix-flakes-experimental

# 2. Dry-run build
./quick-vm-test.sh --dry-run

# 3. Full VM test (if all good)
./quick-vm-test.sh --run

# 4. Test features in VM via SSH
ssh -p 2222 testuser@localhost

# 5. If successful, deploy to hardware
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi
```

## 🐛 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| **QEMU not found** | `sudo apt install qemu-system-x86` or `nix-env -iA nixpkgs.qemu` |
| **KVM not available** | Enable virtualization in BIOS, check CPU support |
| **Disk too small** | Increase disk size: `-drive file=...,size=100G` |
| **SSH won't connect** | Check firewall: `sudo ufw allow 2222/tcp` |
| **Build fails** | Run with `--show-trace` for detailed errors |

## 🎯 Next Steps

After successful VM testing:

1. **Review test results** - Did all features work?
2. **Check performance** - Any slowdowns or issues?
3. **Validate rollback plan** - Can you revert if needed?
4. **Deploy to hardware** - Use same configuration on actual system
5. **Monitor after deploy** - Watch for any runtime issues

---

**Remember:** VM testing saves time and prevents costly mistakes! Test thoroughly, then deploy with confidence. 🚀
