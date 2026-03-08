# NixOS Experimental Configuration - Feature Flags System

**A modular build system that lets you selectively enable/disable features to avoid long build times!**

---

## 🎯 What Is This?

This is an **experimental configuration** of the original `nix-flakes` setup, enhanced with **feature flags** that control what gets built. 

### The Problem It Solves
The original NixOS configuration includes hundreds of packages and services. Building everything can take:
- **90-180 minutes** on average hardware
- **100+ GB** disk space

With feature flags, you can build only what you need in:
- **5-30 minutes** depending on your choices
- **8-40 GB** disk space

---

## 📁 Files Created

| File | Purpose |
|------|---------|
| `feature-flags.nix` | Main feature flag configuration file (edit this!) |
| `FEATURE_FLAGS_GUIDE.md` | Detailed guide explaining each feature and its impact |
| `FEATURE_COVERAGE_MAP.md` | Maps every original feature to its controlling flag |
| `QUICK_FLAG_REFERENCE.md` | Quick reference card for common configurations |
| `SETUP_AND_USAGE.md` | Step-by-step setup instructions and recommended configs |

---

## 🚀 Quick Start (2 Minutes)

### 1. Choose Your Configuration Type
Pick one of the pre-made configurations below based on your needs:

**Minimal Server:** Fastest build (~5 min), no GUI, no gaming, no AI
**Developer Desktop:** Balanced (~15-20 min), full dev tools but no AI
**Gaming Desktop:** (~25-35 min), optimized for games and media
**AI/ML Workstation:** (~60-90 min), all AI features enabled
**MacBook T2:** (~30-45 min), optimized for Apple hardware

### 2. Edit the Feature Flags
```bash
# Open the feature flags file
nano ~/sources/nix-flakes-experimental/feature-flags.nix

# Change boolean values (true/false) based on your chosen configuration
# See SETUP_AND_USAGE.md or QUICK_FLAG_REFERENCE.md for suggestions
```

### 3. Rebuild Your System
```bash
# For baremetal x86_64 (esnixi)
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi

# For MacBook T2 (macland)
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#macland
```

---

## 📋 Feature Flag Categories

### ⚡ Core Features (ALWAYS TRUE - Never Disable!)
- `enableCoreSystem` - Essential system services, user setup, bootloader

### 🖥️ Desktop Environment (~5-10 min impact)
- `enableDesktopEnvironment` - Hyprland window manager and Quickshell
- `enableToucheggGestures` - Touchégg gesture support for touchpads
- `enableKeydRemapping` - keyd keyboard remapping daemon
- `enableTheming` - Custom cursors, GTK themes, appearance

### 🎮 Gaming & Entertainment (~10-15 min impact)
- `enableGaming` - Steam, Protontricks, GameMode, Mangohud
- `enableVRSupport` - ALVR, WiVRn for VR streaming
- `enableMediaPlayers` - mpv, vlc, Spotify, Tidal-Hifi

### 💻 Development Tools (~30-60 min impact) **HEAVY!**
- `enableDevelopmentTools` - VSCode, JetBrains, compilers, languages
  - `enableVSCode` - VSCode with extensions
  - `enableJetBrains` - JetBrains Toolbox
  - `enablePythonDev` - Python + CUDA support (**VERY HEAVY!**)
  - `enableNodeJS` - Node.js and npm packages
  - `enableJava` - OpenJDK
  - `enableCMakeBuildTools` - CMake, Meson, Ninja
  - `enableKubernetes` - k3s, Helm, Kustomize (**VERY HEAVY!**)

### 🤖 AI & Machine Learning (~60-90 min impact) **VERY HEAVY!**
- `enableAIService` - Ollama local LLM server
  - `enableOllama` - Local LLM inference with CUDA/ROCm (**VERY VERY HEAVY!**)
  - `enableComfyUI` - ComfyUI image generation service (**HEAVY!**)
  - `enableMCP` - Model Context Protocol servers (MODERATE)

### 🖥️ Virtualization & Containers (~10-20 min impact)
- `enableVirtualization` - Docker, QEMU/KVM, libvirt
  - `enableDocker` - Docker with NVIDIA support
  - `enableQEMU` - QEMU/KVM virtualization
  - `enableWindowsVM` - Pre-configured Windows VM container

### 🌍 Platform-Specific Features (Must Match Hardware!)
- `enableNVIDIA` - NVIDIA drivers, CUDA support (**esnixi only**)
- `enableAMDGPU` - AMD GPU with ROCm support (**macland only**)
- `enableMacBookT2` - T2 chip, Touch Bar, fan control (**macland only**)

### 🔧 Optional Tools (Low Impact)
- `enableMonitoringTools` - btop, iotop, iftop, strace
- `enableRemoteAccess` - FreeRDP, wlvncc for remote desktop
- `enableAudioEffects` - EasyEffects, LADSPA plugins
- `enableFonts` - Extended font packages

---

## 📊 Build Time & Disk Usage Reference

| Configuration | Build Time | Disk Usage | Best For |
|--------------|------------|------------|----------|
| **Minimal Server** | 5-10 min | ~8 GB | Headless servers, VPS |
| **Basic Desktop** | 15-20 min | ~25 GB | General desktop use |
| **Developer** | 20-30 min | ~35 GB | Software development |
| **Gaming** | 25-35 min | ~40 GB | Gaming desktops |
| **AI/ML Workstation** | 60-90 min | ~70+ GB | Machine learning work |
| **Full Build (all enabled)** | 90-180 min | ~100+ GB | Evaluation purposes only ⚠️ |

---

## 🎯 Recommended Configurations by Use Case

### Minimal Server (Fastest)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = false;
enableGaming = false;
enableDevelopmentTools = false;
enableAIService = false;
enableVirtualization = false;
enableMonitoringTools = true;   # Optional but useful
enableSecurityFeatures = true;
enableBluetooth = true;
```

### Developer Desktop (Balanced)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableDevelopmentTools = true;  # Enable this!
enableVSCode = true;
enablePythonDev = true;         # Essential for Python dev work
enableKubernetes = false;       # Disable unless you need it!

enableAIService = false;        # Disable to save build time
```

### Gaming Desktop
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableGaming = true;            # Enable this!
enableMediaPlayers = true;

enableDevelopmentTools = true;  # Optional but useful
enableAIService = false;        # Disable to save resources
```

### AI/ML Workstation
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableDevelopmentTools = true;  # Essential!
enablePythonDev = true;         # Essential for ML work!

enableAIService = true;         # Enable this!
enableOllama = true;            # Essential for local LLMs!
enableComfyUI = true;           # For image generation work
```

### MacBook T2 (Apple Hardware)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableAMDGPU = true;            # Enable AMD support for T2 Macs
enableNVIDIA = false;           # Disable NVIDIA (not applicable)
enableMacBookT2 = true;         # Enable T2-specific features

enableAIService = false;        # ROCm on T2 is experimental
```

---

## ⚠️ Critical Warnings

1. **NEVER disable `enableCoreSystem`** - This will break your boot!
2. **Match platform flags to your hardware:**
   - NVIDIA GPU → `enableNVIDIA = true`, `enableAMDGPU = false`
   - AMD GPU/Mac T2 → `enableNVIDIA = false`, `enableAMDGPU = true`
3. **AI features are VERY heavy** - Only enable if actively using!
4. **Kubernetes adds significant build time** - Disable unless needed!
5. **Python + CUDA is HEAVY** - Consider disabling if not doing ML work

---

## 🔄 How to Switch Between Configurations

### Method 1: Direct Edit (Recommended)
```bash
# Edit the feature flags file directly
nano ~/sources/nix-flakes-experimental/feature-flags.nix

# Change boolean values based on your current needs
# Rebuild after editing
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi
```

### Method 2: Multiple Config Files (Advanced)
```bash
# Create separate config files for different scenarios
cp feature-flags.nix feature-minimal.nix
cp feature-flags.nix feature-dev.nix
cp feature-flags.nix feature-gaming.nix
cp feature-flags.nix feature-ai.nix

# Edit each file with its specific configuration

# Use specific config when rebuilding
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi \
  -I featureFlags=feature-minimal.nix
```

---

## 📚 Documentation Files Explained

| File | When to Read This |
|------|------------------|
| `SETUP_AND_USAGE.md` | **START HERE** for step-by-step instructions |
| `FEATURE_FLAGS_GUIDE.md` | Want detailed explanations of each feature? |
| `FEATURE_COVERAGE_MAP.md` | Need to know exactly what each flag controls? |
| `QUICK_FLAG_REFERENCE.md` | Want a quick reference card for common configs? |
| This file (`README_EXPERIMENTAL.md`) | **Overview** and getting started |

---

## 🎯 Next Steps

1. **Read SETUP_AND_USAGE.md** for detailed instructions
2. **Choose your configuration type** from the recommended configurations above
3. **Edit feature-flags.nix** to match your needs
4. **Rebuild with:** `sudo nixos-rebuild switch --flake ...`
5. **Verify features are enabled** with: `systemctl list-unit-files | grep ...`
6. **Enjoy your optimized system!** 🚀

---

## 🔗 Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Documentation](https://nix-community.github.io/home-manager/)
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Ollama Docs](https://github.com/ollama/ollama)
- [ComfyUI GitHub](https://github.com/comfyanonymous/ComfyUI)

---

## 💡 Pro Tips

1. **Start minimal, add features as needed** - Don't enable everything at once!
2. **Use caching** - After first full build, subsequent builds are much faster
3. **Monitor disk space** - Full build can use 100+ GB
4. **Feature flags persist across rebuilds** - Once set, they stay until changed
5. **Test with dry-run first** - `sudo nixos-rebuild switch --dry-run` to see changes

---

**Happy building! Remember: Less is more for faster builds. You can always re-enable features later when you need them!** 🎉
