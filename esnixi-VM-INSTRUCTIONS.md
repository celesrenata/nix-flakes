# VM Testing Instructions for esnixi Server

## 📦 Files Sent to esnixi

The following files have been copied to your esnixi server:

```
/home/celes/sources/nix-flakes-experimental/
├── quick-vm-test.sh              # Quick one-command testing
├── test-vm-methods.sh            # Interactive testing menu
├── select-gpu-kernel.sh          # GPU/kernel selection helper
├── setup-vm-testing.sh           # Setup script for esnixi
├── VM_TESTING_COMPLETE.md        # Complete guide
└── vm-test-configuration.nix     # Test configuration template
```

## 🚀 Quick Start (Run These Commands on esnixi)

### Step 1: Navigate to the directory
```bash
cd ~/sources/nix-flakes-experimental
```

### Step 2: Run the setup script
```bash
./setup-vm-testing.sh
```

This will:
- ✅ Check all required files are present
- ✅ Make scripts executable
- ✅ Verify system requirements (NixOS, QEMU)
- ✅ Show current GPU/kernel configuration

**Expected output:**
```
✓ All required files present
✓ Scripts are now executable
✓ System requirements met
Setup complete!
```

### Step 3: Test Configuration Syntax (Recommended First!)
```bash
./quick-vm-test.sh --dry-run
```

This will check if your configuration compiles without errors. **No changes to system!**

**If successful, you'll see:**
```
✓ Flake syntax valid
Configuration built successfully!
```

### Step 4: Choose GPU & Kernel Configuration (Optional)
Before running full tests, decide which GPU/kernel combination to test:

```bash
# Option A: NVIDIA + Linux 6.19 (your original setup)
./select-gpu-kernel.sh nvidia 6_19

# Option B: AMD ROCm + Linux 6.12  
./select-gpu-kernel.sh rocm 6_12
```

Then verify selection:
```bash
./select-gpu-kernel.sh show
```

### Step 5: Build VM Configuration (No QEMU)
```bash
sudo nixos-rebuild build --flake .#esnixi --dry-run
```

This builds the configuration without applying it to your system. **Safe for testing!**

**Expected output:**
```
building the system configuration...
Done. The new configuration is /nix/store/...-esnixi-25.11
```

### Step 6: Full VM Test (Requires QEMU)
If you have QEMU installed, run a full VM test:

```bash
./quick-vm-test.sh --run
```

**What happens:**
1. Builds NixOS system configuration
2. Creates 60GB virtual disk image
3. Launches QEMU with your config (8GB RAM, 4 CPU cores)
4. Forwards SSH port 2222 to VM

**After QEMU starts:**
- Press **Ctrl+A**, then press **X** to exit QEMU console
- SSH into VM from host: `ssh -p 2222 testuser@localhost`
- Password: `test123`

## 🐛 Troubleshooting on esnixi

### Issue: "QEMU not installed"
```bash
# Install QEMU system tools
sudo apt install qemu-system-x86
```

### Issue: "KVM not available"
```bash
# Enable virtualization in BIOS settings
# Or check if your CPU supports KVM:
lscpu | grep -i kvm

# If needed, enable nested virtualization for testing
sudo modprobe kvm_intel  # or kvm_amd depending on CPU
```

### Issue: "Build failed"
```bash
# Get detailed error output
./quick-vm-test.sh --dry-run --show-trace

# Or manually with verbose output:
sudo nixos-rebuild build --flake .#esnixi \
    --option builders-use-substitutes true \
    --show-trace 2>&1 | less
```

### Issue: "SSH won't connect to VM"
```bash
# Check port forwarding is active
lsof -i :2222

# Or check firewall settings
sudo ufw allow 2222/tcp
```

## 🎯 Complete Testing Workflow

```bash
# On esnixi server:

cd ~/sources/nix-flakes-experimental

# Step 1: Setup environment
./setup-vm-testing.sh

# Step 2: Test configuration syntax (no changes)
./quick-vm-test.sh --dry-run

# Step 3: Choose GPU/kernel combination
./select-gpu-kernel.sh nvidia 6_19    # or rocm 6_12

# Step 4: Build without running QEMU
sudo nixos-rebuild build --flake .#esnixi --dry-run

# Step 5: Full VM test (if all above passed)
./quick-vm-test.sh --run

# Step 6: SSH into VM to test features
ssh -p 2222 testuser@localhost
password: test123

# Step 7: If successful, deploy to hardware!
sudo nixos-rebuild switch --flake .#esnixi
```

## 🛡️ Safety Checklist Before Deploying

- [ ] Configuration syntax validated (step 2)
- [ ] Build completed without errors (step 4)
- [ ] VM boots successfully (step 6)
- [ ] SSH access works (step 7)
- [ ] All required features work in VM
- [ ] No critical warnings or errors

## 📞 Need Help?

If you encounter issues:

1. **Check setup script output** - Did all checks pass?
2. **Review dry-run output** - Any syntax errors shown?
3. **Test with different GPU/kernel** - Try rocm 6_12 if nvidia fails
4. **Run with --show-trace** for detailed error messages
5. **Check esnixi specs** - Ensure sufficient RAM/CPU/disk space

## 🎯 Next Steps After Testing

Once VM testing is successful:

```bash
# Deploy to actual hardware (esnixi server)
sudo nixos-rebuild switch --flake .#esnixi

# Or if you want to keep current config as fallback:
sudo nixos-rebuild boot --flake .#esnixi  # Test boot without rebooting

# Monitor after deployment:
journalctl -f
systemctl status nix-daemon
```

---

**You're all set to test your NixOS flake configuration safely!** 🚀

The VM testing process ensures you can try new features, kernel changes, and GPU configurations before deploying to production hardware. Test thoroughly, then deploy with confidence!
