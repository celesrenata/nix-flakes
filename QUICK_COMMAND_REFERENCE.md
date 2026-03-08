# 🚀 Quick Command Reference - NixOS Experimental Flake

## 🔧 Essential Commands

### Build & Deployment

```bash
# Test build without deploying (recommended first step)
nixos-rebuild build --flake .#esnixi

# Dry-run deployment (shows what would change)
sudo nixos-rebuild switch --flake .#esnixi --dry-run

# Deploy to production ESXi server
sudo nixos-rebuild switch --flake .#esnixi

# Build MacBook T2 configuration (for testing)
nixos-rebuild build --flake .#macland

# Deploy MacBook T2 configuration
sudo nixos-rebuild switch --flake .#macland

# Reboot into new generation
sudo nixos-reboot
```

### Validation & Debugging

```bash
# Check flake evaluates correctly
nix flake show --all-systems

# View build logs
journalctl -u nix-daemon -f

# Check GPU status (NVIDIA)
nvidia-smi

# Check GPU status (AMD/ROCm)
rocminfo

# List loaded kernel modules
lsmod | grep -E 'nvidia|amdgpu'

# Check Ollama service status
systemctl status ollama

# Query Ollama API
curl http://localhost:11434/api/tags

# View NixOS generations (for rollback)
nixos-rebuild list-generations

# Boot into specific generation
sudo nixos-reboot --option generatation <number>
```

### Backup & Restore

```bash
# Create backup of current system
./backup-esnixi.sh

# Restore from backup
./restore-esnixi.sh

# Check available backups
ls -lh /home/celes/*.tar*
```

### VM Testing (Safe Before Hardware Deploy)

```bash
# Run quick QEMU VM test
./quick-vm-test.sh

# Test specific configuration in VM
./test-flake-vm.sh esnixi

# Check VM bridge networking
./verify-bridge.sh

# Setup VM testing environment
./setup-vm-testing.sh
```

### Git Operations

```bash
# View current status
git status

# Review changes before commit
git diff

# Stage all fixes for commit
git add esnixi/gpu-kernel-flags.nix overlays/comfyui.nix

# Commit with descriptive message
git commit -m "fix(esnixi): resolve gpu-kernel-flags syntax error and update ComfyUI URLs"

# Push to remote repository
git push origin main
```

### Feature Flag Management

```bash
# Edit feature flags (open in your editor)
nano feature-flags.nix
vim feature-flags.nix
code feature-flags.nix

# Search for specific flag settings
grep -n "enable.*= true" feature-flags.nix

# Check which features are enabled
cat feature-flags.nix | grep "^[[:space:]]*enable" | grep "= true"
```

### Package & Build Management

```bash
# List all available packages in current system
nix-env -q

# Search for specific package
nix search nixpkgs <package-name>

# Build specific package
nix build .#nixosConfigurations.esnixi.config.system.build.toplevel

# Check disk space usage
df -h /

# View Nix store size
du -sh /nix/store | sort -hr | head -20
```

### Remote Operations (if configured)

```bash
# Build remotely on another machine
nix build --option builders "ssh://user@remote-host#" .#esnixi

# Deploy to remote system
sudo nixos-rebuild switch --host user@remote-host --flake .#esnixi

# Sync configuration between systems
rsync -avz ./ celes@remote:/home/celes/sources/nix-flakes-experimental/
```

---

## 🎯 Common Workflows

### Workflow 1: Quick Configuration Test
```bash
# 1. Make a small change to configuration.nix
nano configuration.nix

# 2. Build without deploying
nixos-rebuild build --flake .#esnixi

# 3. If successful, switch and reboot
sudo nixos-rebuild switch --flake .#esnixi
```

### Workflow 2: Full Production Deployment
```bash
# 1. Review all changes
git diff HEAD

# 2. Commit any uncommitted work
git add -A
git commit -m "Pre-deployment snapshot"

# 3. Test build
nixos-rebuild build --flake .#esnixi

# 4. Dry-run deployment
sudo nixos-rebuild switch --flake .#esnixi --dry-run

# 5. Deploy to production
sudo nixos-rebuild switch --flake .#esnixi

# 6. Verify system health
nvidia-smi && systemctl status ollama && docker ps
```

### Workflow 3: Rollback Failed Deployment
```bash
# 1. List available generations
nixos-rebuild list-generations

# 2. Boot into previous working generation
sudo nixos-reboot --option generatation <number>

# 3. Investigate what went wrong
journalctl -xb | grep -i error

# 4. Fix configuration and rebuild
nano feature-flags.nix  # or other file
nixos-rebuild build --flake .#esnixi
```

### Workflow 4: Feature Flag Experimentation
```bash
# 1. Backup current flags
cp feature-flags.nix feature-flags.nix.backup

# 2. Modify a single flag for testing
sed -i 's/enableOllama = true;/enableOllama = false;/' feature-flags.nix

# 3. Test build impact
time nixos-rebuild build --flake .#esnixi

# 4. If successful, commit and deploy
git add feature-flags.nix
git commit -m "feat: disable Ollama to reduce build time"
sudo nixos-rebuild switch --flake .#esnixi
```

---

## 🔍 Diagnostic Commands

### System Health Checks

```bash
# Full system health report
systemctl status

# CPU and memory usage
top -bn1 | head -20

# Disk space by directory
du -sh /* 2>/dev/null | sort -hr | head -10

# Network connectivity test
ping -c 4 github.com
curl -I https://github.com
```

### GPU & Acceleration Verification

```bash
# NVIDIA verification
nvidia-smi
glxinfo | grep "OpenGL renderer"

# AMD/ROCm verification
rocminfo
glxinfo | grep "OpenGL renderer"

# Check if CUDA is accessible
nvcc --version  # NVIDIA
HIP_PATH= rocminfo  # AMD ROCm
```

### Service Status Checks

```bash
# Ollama service
systemctl status ollama
journalctl -u ollama --no-pager -n 50

# ComfyUI (if enabled as service)
systemctl status comfyui 2>/dev/null || echo "ComfyUI not running as service"

# Docker daemon
systemctl status docker
docker info | grep -E "Server Version|Storage Driver|Operating System"

# Wayland compositor
echo $XDG_SESSION_TYPE  # Should return 'wayland' for Hyprland
```

---

## 🛠️ Troubleshooting Quick Fixes

### Issue: Build fails with syntax error
```bash
# Check for trailing semicolons in module files
grep -rn "};$" esnixi/*.nix macland/*.nix | grep -v "//"

# Validate Nix syntax
nix-instantiate --eval -E '(import <nixpkgs> {}).lib.nixosSystem { modules = [ ./esnixi/gpu-kernel-flags.nix ]; }'
```

### Issue: GPU driver not loading after reboot
```bash
# Check if kernel module is loaded
lsmod | grep nvidia  # or amdgpu for AMD

# Force reload if needed
sudo modprobe nvidia  # or amdgpu

# Verify X server config
grep -A3 "videoDrivers" /run/current-system/sw/etc/nixos/configuration.nix
```

### Issue: Ollama won't start
```bash
# Check service logs
journalctl -u ollama -f

# Test CUDA/ROCm availability
nvidia-smi  # NVIDIA
rocminfo    # AMD

# Verify Ollama configuration
cat /etc/systemd/system/ollama.service.d/override.conf 2>/dev/null || echo "No override found"
```

### Issue: ComfyUI returns 404 for workflows
```bash
# Check overlay file has correct URLs
grep -A5 "comfyui-valid-templates" overlays/comfyui.nix

# Verify workflow template repository is accessible
curl -I https://raw.githubusercontent.com/Comfy-Org/workflow_templates/main/templates/01_get_started_text_to_image.json

# Rebuild ComfyUI overlay if needed
nix build .#comfyui --no-link
```

---

## 📊 Performance Monitoring

### Build Time Tracking
```bash
# Measure build time for full configuration
time nixos-rebuild build --flake .#esnixi

# Track individual feature impact by disabling/enabling in feature-flags.nix
```

### Runtime Resource Usage
```bash
# Monitor current resource usage
htop
iotop
iftop

# Check service-specific memory usage
systemctl status ollama  # Shows memory usage
docker stats             # Container memory usage
```

---

## 🎓 Advanced Operations

### Custom Package Override
```nix
# In flake.nix, add to overlays list:
(overlay: final: prev: {
  my-custom-package = prev.my-package.overrideAttrs (old: {
    version = "custom-version";
    # ... customizations
  });
})
```

### Remote Build Optimization
```bash
# Configure remote builders in /etc/nix/nix.conf
builders = ssh://user@remote-host#ssh://user@another-host#
max-jobs = auto
```

### NixOS Configuration Customization
```bash
# Generate new hardware-configuration.nix for your system
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix

# Rebuild with new configuration
nixos-rebuild switch --flake .#esnixi
```

---

## 📚 Additional Resources

### Documentation Files
```bash
cat CONFIGURATION.md          # Full system guide
cat FEATURE_FLAGS_GUIDE.md    # Feature flags documentation
cat VM_TESTING_COMPLETE.md    # QEMU testing procedures
cat DEPLOYMENT_STATUS.md      # Current deployment status
```

### Scripts Available
```bash
ls -lh *.sh                   # List all available scripts
./quick-vm-test.sh            # Safe VM testing before hardware deploy
./select-gpu-kernel.sh        # GPU/kernel selection helper
./backup-esnixi.sh           # Create system backup
./restore-esnixi.sh          # Restore from backup
```

---

## 🎯 Quick Reference Card

| Task | Command |
|------|---------|
| Test build | `nixos-rebuild build --flake .#esnixi` |
| Dry-run deploy | `sudo nixos-rebuild switch --flake .#esnixi --dry-run` |
| Deploy production | `sudo nixos-rebuild switch --flake .#esnixi` |
| Check GPU status | `nvidia-smi` or `rocminfo` |
| View generations | `nixos-rebuild list-generations` |
| Rollback | `sudo nixos-reboot --option generatation <number>` |
| Test VM safely | `./quick-vm-test.sh` |
| Create backup | `./backup-esnixi.sh` |

**Remember:** Always test changes with a build first, then dry-run deployment before actual production deployment!

