# GPU Selection Platform Guide - Which Platform Uses What?

## 🎯 Quick Reference

| Platform | Hardware | GPU Type | Default Setting |
|----------|----------|----------|-----------------|
| **esnixi** | ESXi Baremetal Server | NVIDIA (with CUDA) | `enableNVIDIA = true` |
| **macland** | MacBook T2 | AMD ROCm | `enableROCM = true` |

---

## 📋 Configuration Files by Platform

### esnixi/gpu-kernel-flags.nix (For ESXi Server)
```nix
# GPU & Kernel Selection Configuration Module for ESXi (NVIDIA-focused)
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.gpu-selection;
in {

  options.boot.gpu-selection = {
    enableNVIDIA = mkOption {
      type = types.bool;
      default = true;  # ESXi uses NVIDIA GPUs with CUDA support
      description = "Enable NVIDIA GPU support";
    };
    
    enableROCM = mkOption {
      type = types.bool;
      default = false;  # ROCm is for macland (MacBook T2)
      description = "Enable AMD ROCm support";
    };
  };

  config = mkIf cfg.enableNVIDIA {
    
    services.xserver.videoDrivers = [ "nvidia" ];
    
  } // mkIf cfg.enableROCM {
    
    # This won't be used for esnixi, but kept for completeness
    services.xserver.videoDrivers = [ "amdgpu" ];
    
  };

}
```

**Purpose:** Configure NVIDIA drivers and kernel modules for ESXi baremetal server.

---

### macland/gpu-kernel-flags.nix (For MacBook T2) - *To be created*
```nix
# GPU & Kernel Selection Configuration Module for MacBook T2 (AMD-focused)
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.gpu-selection;
in {

  options.boot.gpu-selection = {
    enableNVIDIA = mkOption {
      type = types.bool;
      default = false;  # MacBook T2 uses AMD GPU with ROCm
      description = "Enable NVIDIA GPU support";
    };
    
    enableROCM = mkOption {
      type = types.bool;
      default = true;   # MacBook T2 uses AMD ROCm for compute
      description = "Enable AMD ROCm support";
    };
  };

  config = mkIf cfg.enableNVIDIA {
    
    services.xserver.videoDrivers = [ "nvidia" ];
    
  } // mkIf cfg.enableROCM {
    
    # MacBook T2 uses AMD GPU with ROCm acceleration
    services.xserver.videoDrivers = [ "amdgpu" ];
    
  };

}
```

**Purpose:** Configure AMD drivers and ROCm support for MacBook T2.

---

## 🔄 How to Override Defaults

### For esnixi (ESXi Server)
If you need to disable NVIDIA support temporarily:

```nix
# In feature-flags.nix or a local override file
{ config, lib, ... }:

{
  boot.gpu-selection.enableNVIDIA = false;
}
```

### For macland (MacBook T2) - *Future*
If you need to disable ROCm support:

```nix
# In feature-flags.nix or a local override file
{ config, lib, ... }:

{
  boot.gpu-selection.enableROCM = false;
}
```

---

## ⚙️ Platform-Specific Considerations

### ESXi Server (esnixi) - NVIDIA Focus

**Hardware:**
- Baremetal server with NVIDIA GPU(s)
- CUDA acceleration for AI/ML workloads
- High-performance computing requirements

**Recommended Settings:**
```nix
boot.gpu-selection.enableNVIDIA = true;  # ✅ Required for GPU support
boot.gpu-selection.enableROCM = false;   # ❌ Not applicable (AMD GPUs not present)
```

**Why NVIDIA?**
- CUDA ecosystem for AI/ML tools (Ollama, ComfyUI, etc.)
- Better driver support on ESXi hypervisor
- Industry standard for GPU acceleration in servers

---

### MacBook T2 (macland) - AMD Focus

**Hardware:**
- Apple MacBook with T2 security chip
- Integrated AMD Radeon Pro 5500M GPU
- ROCm compute capabilities via HSA

**Recommended Settings:**
```nix
boot.gpu-selection.enableNVIDIA = false; # ❌ Not applicable (no NVIDIA GPU)
boot.gpu-selection.enableROCM = true;    # ✅ Required for GPU acceleration
```

**Why AMD/ROCm?**
- Native to Apple's integrated graphics
- ROCm provides compute capabilities similar to CUDA
- Open-source driver stack (amdgpu kernel module)

---

## 🚫 Common Mistakes to Avoid

### ❌ Wrong: Using NVIDIA config on MacBook T2
```nix
# DON'T do this!
boot.gpu-selection.enableNVIDIA = true;  # No NVIDIA GPU exists!
boot.gpu-selection.enableROCM = false;   # This disables your GPU acceleration!
```

**Result:** System will fail to boot or have no GPU acceleration.

---

### ❌ Wrong: Using AMD config on ESXi Server  
```nix
# DON'T do this!
boot.gpu-selection.enableNVIDIA = false;  # No NVIDIA drivers loaded!
boot.gpu-selection.enableROCM = true;     # No ROCm hardware present!
```

**Result:** System will fail to boot or have no GPU acceleration.

---

## ✅ Correct Usage Examples

### For ESXi Server (esnixi)
```bash
# This is the default configuration for esnixi platform
sudo nixos-rebuild switch --flake .\#esnixi

# Verify NVIDIA drivers are loaded:
nvidia-smi  # Should show GPU information
lsmod | grep nvidia  # Should show kernel modules loaded
```

### For MacBook T2 (macland) - *Future*
```bash
# This is the default configuration for macland platform  
sudo nixos-rebuild switch --flake .\#macland

# Verify AMD drivers are loaded:
rocminfo  # Should show ROCm devices
lsmod | grep amdgpu  # Should show kernel modules loaded
```

---

## 🔧 Troubleshooting GPU Issues

### Issue: NVIDIA module not found in kernel
**Cause:** `enableNVIDIA` is false but system expects NVIDIA drivers.  
**Solution for esnixi:**
```bash
# Check current settings
nixos-rebuild show-config | grep gpu-selection

# If needed, temporarily override:
sudo nixos-rebuild switch --flake .\#esnixi \
  -I nixpkgs.config.boot.gpu-selection.enableNVIDIA=true
```

### Issue: ROCm devices not detected on MacBook T2
**Cause:** `enableROCM` is false but system expects AMD drivers.  
**Solution for macland:**
```bash
# Check current settings
nixos-rebuild show-config | grep gpu-selection

# If needed, temporarily override:
sudo nixos-rebuild switch --flake .\#macland \
  -I nixpkgs.config.boot.gpu-selection.enableROCM=true
```

---

## 📚 Related Documentation

| Document | Purpose |
|----------|---------|
| `DEPLOYMENT_STATUS.md` | Overall deployment status and timeline |
| `FEATURE_FLAGS_QUICK_REFERENCE.md` | Feature flags quick reference |
| `VM_IMAGE_BUILDING_GUIDE.md` | How to build VM disk images from configurations |

---

## 🎯 Summary

**Key Takeaway:** Each platform has a different GPU architecture:
- **esnixi (ESXi)** → NVIDIA + CUDA = Production AI/ML server
- **macland (MacBook T2)** → AMD + ROCm = Portable development machine

Always use the correct configuration for your hardware! 🎉

