# 🚀 Remote Deployment Guide - NixOS Experimental Flake

## ⚠️ Important: Don't Copy Build Results!

**Problem:** The `result` directory and Nix store can contain **50-100GB+** of build artifacts that you don't need to transfer.

**Solution:** Use one of the methods below to deploy without copying unnecessary data.

---

## 🎯 Deployment Methods (Ranked by Recommendation)

### Method 1: Remote Build + Deploy (BEST FOR MOST USE CASES ⭐⭐⭐⭐⭐)

Let the remote host build locally using its own Nix store cache.

#### Setup (One-time):
```bash
# Configure SSH key authentication to remote host
ssh-copy-id user@esxi-server

# Optionally, add remote host as a build machine in nix.conf
echo "builders = ssh://user@esxi-server#" | sudo tee -a /etc/nix/nix.conf
sudo systemctl restart nix-daemon.service
```

#### Deploy:
```bash
# Option A: Using --host flag (simplest)
sudo nixos-rebuild switch \
    --host user@esxi-server \
    --flake .\#esnixi

# Option B: Using remote build machine explicitly
sudo nixos-rebuild switch \
    --option builders "ssh://user@esxi-server#" \
    --flake .\#esnixi
```

**Pros:**
- ✅ No file transfer (fastest for large configs)
- ✅ Uses remote host's Nix cache (faster builds)
- ✅ Only config files referenced in flake are needed on remote

**Cons:**
- ⚠️ Requires SSH access to remote host
- ⚠️ Remote host must have nix flakes enabled

---

### Method 2: Copy Source Files Only (GOOD FOR AIR-GAPPED SYSTEMS ⭐⭐⭐)

Transfer only the configuration files, not build results.

#### Setup Script:
```bash
# Use the included deploy script
./deploy-remote.sh user@esxi-server esnixi
```

#### Manual Method:
```bash
# From local machine (create clean tarball)
cd /home/celes/sources/nix-flakes-experimental
tar --exclude='result' \
    --exclude='.nix-output-monitor' \
    -czf nixos-config.tar.gz \
    flake.nix feature-flags.nix configuration.nix esnixi/ macland/ overlays/ home/

# Transfer to remote host
scp nixos-config.tar.gz user@esxi-server:/tmp/

# On remote host (extract and deploy)
ssh user@esxi-server "
    cd /tmp
    tar -xzf nixos-config.tar.gz
    sudo nixos-rebuild switch --flake .\#esnixi
"
```

**Pros:**
- ✅ Works with any SSH-capable host
- ✅ No remote build machine configuration needed
- ✅ Good for one-time deployments or air-gapped systems

**Cons:**
- ⚠️ Requires manual file transfer (~10MB)
- ⚠️ Remote host must have all dependencies cached locally
- ⚠️ Slower first time (all packages need to be built/downloaded)

---

### Method 3: Git Repository Reference (BEST FOR PRODUCTION ⭐⭐⭐⭐⭐)

Push your flake to a Git repository and reference it directly.

#### Setup:
```bash
# Push changes to remote repository
git push origin main

# Ensure the repo is publicly accessible or add SSH key on remote host
ssh-add ~/.ssh/id_rsa  # Add SSH key if private repo
```

#### Deploy from Remote Host:
```bash
sudo nixos-rebuild switch \
    --flake 'git+ssh://git@github.com/youruser/nix-flakes-experimental\#esnixi'
```

**Pros:**
- ✅ Zero file transfer (pure Git reference)
- ✅ Always deploy latest committed configuration
- ✅ Built-in version history via Git tags
- ✅ Works with any NixOS host that can clone the repo

**Cons:**
- ⚠️ Requires public repository or SSH key setup on remote hosts
- ⚠️ Network access needed to fetch flake sources

---

### Method 4: Nix Flake Registry (BEST FOR ENTERPRISE ⭐⭐⭐⭐⭐)

Publish your flake to the nix registry for fastest deployments.

#### Setup:
```bash
# Register your flake with a remote Nix registry
nix flake publish \
    --to ssh://user@esxi-server \
    git+file:///home/celes/sources/nix-flakes-experimental

# Or use the public flakes registry (requires setup)
nix flake publish git+https://github.com/youruser/nix-flakes-experimental
```

#### Deploy:
```bash
sudo nixos-rebuild switch \
    --flake 'github:youruser/nix-flakes-experimental\#esnixi'
```

**Pros:**
- ✅ Fastest deployment (no Git clone needed)
- ✅ Immutable flake references for reproducibility
- ✅ Built-in caching via registry
- ✅ Works across multiple hosts efficiently

**Cons:**
- ⚠️ Requires initial setup and registration
- ⚠️ Best suited for production environments with multiple hosts

---

## 📋 Quick Comparison Table

| Method | File Transfer | Speed | Complexity | Best For |
|--------|--------------|-------|------------|----------|
| Remote Build | None | ⭐⭐⭐⭐⭐ Fastest | Low | Regular deployments, large configs |
| Source Files Only | ~10MB config | ⭐⭐⭐ Medium | Very Low | Air-gapped systems, one-time deploy |
| Git Repository | None (Git fetch) | ⭐⭐⭐⭐ Fast | Low | Production, version control integration |
| Flake Registry | None (Registry cache) | ⭐⭐⭐⭐⭐ Fastest | High | Enterprise, multiple hosts |

---

## 🔧 Pre-Deployment Checklist

Before deploying to a remote host:

### SSH Access
```bash
# Verify SSH key authentication works without password
ssh -o BatchMode=yes user@esxi-server exit 0
```

### Remote Host Requirements
```bash
# Ensure nix flakes are enabled on remote host
grep "experimental-features" /etc/nix/nix.conf | grep -q "flakes" || echo "Enable flakes first!"

# Verify network access to flake sources (GitHub)
curl -I https://github.com  # Should return HTTP 200
```

### Configuration Verification
```bash
# Review feature flags before deployment
cat /home/celes/sources/nix-flakes-experimental/feature-flags.nix | grep "= true"

# Check disk space on remote host (need ~50GB for full build)
ssh user@esxi-server "df -h /"
```

---

## 🚨 Troubleshooting Remote Deployment Issues

### Issue: "Permission denied (publickey)"
**Solution:** Configure SSH key authentication first
```bash
ssh-copy-id user@esxi-server
```

### Issue: "experimental-features must include 'flakes'"
**Solution:** Enable flakes on remote host
```bash
# On remote host:
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
sudo systemctl restart nix-daemon.service
```

### Issue: Build fails with "cannot fetch from GitHub"
**Solution:** Check network connectivity and firewall rules
```bash
# Test from remote host:
ssh user@esxi-server "curl -I https://github.com"
```

### Issue: Slow first deployment (all packages building)
**Solution:** This is expected! Subsequent deployments will be faster due to caching. Consider using Method 1 or 4 for better performance.

---

## 📝 Deployment Scripts Reference

### Quick Deploy Script
```bash
# Save as ~/bin/deploy-nixos
#!/bin/bash
sudo nixos-rebuild switch \
    --host "${1:-user@esxi-server}" \
    --flake "$2:.\#esnixi"
```

### Verify Deployment Script
```bash
# Save as ~/bin/verify-deployment
#!/bin/bash
ssh user@esxi-server << 'EOF'
    echo "=== System Health ==="
    systemctl status nix-daemon --no-pager | tail -3
    
    echo ""
    echo "=== GPU Status ==="
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    fi
    
    echo ""
    echo "=== Ollama Status ==="
    systemctl is-active ollama && curl -s http://localhost:11434/api/tags | jq '.models[].name' || echo "Not running"
EOF
```

---

## 🎯 Recommended Workflow for Your Setup

Based on your configuration, here's the recommended deployment approach:

### For ESXi Server (esnixi):
```bash
# Method 1: Remote Build + Deploy (recommended)
sudo nixos-rebuild switch \
    --host user@esxi-server \
    --flake .\#esnixi

# Verify after deployment
./verify-deployment.sh user@esxi-server
```

### For MacBook T2 (macland):
```bash
# Method 3: Git Repository Reference (best for portability)
sudo nixos-rebuild switch \
    --flake 'git+ssh://git@github.com/youruser/nix-flakes-experimental\#macland'

# Or copy source files if no network access
./deploy-remote.sh user@macbook macland
```

---

## 🔄 Rollback Strategy for Remote Deployments

If deployment fails on remote host:

### Option 1: Boot into Previous Generation (via GRUB)
```bash
# SSH to remote host and reboot
ssh user@esxi-server "sudo nixos-reboot"

# During boot, select previous generation from GRUB menu
```

### Option 2: NixOS Revert Command
```bash
# List generations
ssh user@esxi-server "nixos-rebuild list-generations"

# Boot into specific generation
ssh user@esxi-server "sudo nixos-reboot --option generatation <number>"
```

### Option 3: Restore from Backup Script
```bash
# If you have backup scripts configured
ssh user@esxi-server "./restore-esnixi.sh"
```

---

## 📚 Additional Resources

- `DEPLOYMENT_STATUS.md` - Current deployment status and timeline
- `QUICK_COMMAND_REFERENCE.md` - Essential commands for daily operations
- `VM_TESTING_COMPLETE.md` - Test configurations safely before remote deploy

**Remember:** Always test changes with a build first, then dry-run deployment before actual production deployment!

