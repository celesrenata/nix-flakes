# NixOS Experimental Configuration - Setup & Usage Guide

## 🚀 Quick Start (5 Minutes)

### 1. Copy Feature Flags File
```bash
cp ~/sources/nix-flakes-experimental/feature-flags.nix \
   ~/sources/nix-flakes-experimental/exnixi/feature-flags-local.nix
```

### 2. Edit the Flags
Open `~/sources/nix-flakes-experimental/esnixi/feature-flags-local.nix` and adjust:
- Set features to `false` that you don't need right now
- See **Recommended Configurations** below for suggestions

### 3. Rebuild Your System
```bash
# For baremetal x86_64 (esnixi)
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi

# For MacBook T2 (macland)
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#macland
```

---

## 📋 Recommended Configurations by Use Case

### 🖥️ Minimal Server (Fastest - ~5 min build)
**Best for:** VPS, headless servers, minimal setups

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

---

### 💻 Developer Desktop (Balanced - ~15-20 min)
**Best for:** Software developers, general desktop use

```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableToucheggGestures = true;
enableKeydRemapping = true;
enableTheming = true;

enableGaming = false;           # Disable if you don't game
enableVRSupport = false;
enableMediaPlayers = true;      # Recommended for most users

enableDevelopmentTools = true;  # Enable this!
enableVSCode = true;
enableJetBrains = true;
enablePythonDev = true;         # Essential for Python dev work
enableNodeJS = true;
enableJava = true;
enableCMakeBuildTools = true;
enableKubernetes = false;       # Disable unless you need Kubernetes!

enableAIService = false;        # Disable to save build time
enableVirtualization = true;    # Optional but useful
```

---

### 🎮 Gaming Desktop (~25-35 min)
**Best for:** Gamers, media consumers

```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableToucheggGestures = true;
enableKeydRemapping = true;

enableGaming = true;            # Enable this!
enableVRSupport = false;        # Only enable if you have VR headset
enableMediaPlayers = true;      # For media consumption

enableDevelopmentTools = true;  # Optional but useful
enableVSCode = true;
enablePythonDev = false;        # Disable unless doing ML work
enableKubernetes = false;       # Not needed for gaming

enableAIService = false;        # Disable to save resources
enableVirtualization = true;    # Can disable if disk space tight
```

---

### 🤖 AI/ML Workstation (~60-90 min)
**Best for:** Machine learning, AI development, research

```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableToucheggGestures = true;

enableGaming = false;           # Disable to prioritize AI resources
enableVRSupport = false;
enableMediaPlayers = false;

enableDevelopmentTools = true;  # Essential for ML work!
enablePythonDev = true;         # Essential! (includes CUDA)
enableNodeJS = true;
enableJava = true;
enableCMakeBuildTools = true;
enableKubernetes = false;       # Can disable if not needed

enableAIService = true;         # Enable this!
enableOllama = true;            # Essential for local LLMs! (VERY HEAVY)
enableComfyUI = true;           # For image generation work (HEAVY)
enableMCP = true;               # For AI assistant integrations

enableVirtualization = false;   # Can disable if disk space tight
```

---

### 🍎 MacBook T2 (~30-45 min)
**Best for:** Apple MacBook with T2 security chip

```nix
# Platform-specific flags (for macland configuration)
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableToucheggGestures = true;
enableKeydRemapping = true;
enableTheming = true;

enableAMDGPU = true;            # Enable AMD support for T2 Macs
enableNVIDIA = false;           # Disable NVIDIA (not applicable)
enableMacBookT2 = true;         # Enable T2-specific features

# Standard flags
enableGaming = false;
enableVRSupport = false;
enableMediaPlayers = true;

enableDevelopmentTools = true;  # Optional but useful
enablePythonDev = false;        # ROCm on T2 is experimental
enableKubernetes = false;

enableAIService = false;        # ROCm support is experimental on T2
enableVirtualization = true;    # Docker works fine on T2
```

---

## 🎯 Feature Flag Quick Reference

### Core Features (ALWAYS TRUE)
- `enableCoreSystem` - Essential system services, user setup, bootloader

### Desktop Environment
- `enableDesktopEnvironment` - Hyprland window manager and Quickshell
- `enableToucheggGestures` - Touchégg gesture support for touchpads
- `enableKeydRemapping` - keyd keyboard remapping daemon
- `enableTheming` - Custom cursors, GTK themes, appearance

### Gaming & Entertainment (Optional)
- `enableGaming` - Steam, Protontricks, GameMode, Mangohud
- `enableVRSupport` - ALVR, WiVRn for VR streaming
- `enableMediaPlayers` - mpv, vlc, Spotify, Tidal-Hifi

### Development Tools (Can Be Very Heavy!)
- `enableDevelopmentTools` - VSCode, JetBrains, compilers, languages
  - `enableVSCode` - VSCode with extensions
  - `enableJetBrains` - JetBrains Toolbox
  - `enablePythonDev` - Python + CUDA support (**HEAVY!**)
  - `enableNodeJS` - Node.js and npm packages
  - `enableJava` - OpenJDK
  - `enableCMakeBuildTools` - CMake, Meson, Ninja
  - `enableKubernetes` - k3s, Helm, Kustomize (**VERY HEAVY!**)

### AI & Machine Learning (VERY HEAVY!)
- `enableAIService` - Ollama local LLM server
  - `enableOllama` - Local LLM inference with CUDA/ROCm (**VERY HEAVY!**)
  - `enableComfyUI` - ComfyUI image generation service (**HEAVY!**)
  - `enableMCP` - Model Context Protocol servers (MODERATE)

### Virtualization & Containers (Optional)
- `enableVirtualization` - Docker, QEMU/KVM, libvirt
  - `enableDocker` - Docker with NVIDIA support
  - `enableQEMU` - QEMU/KVM virtualization
  - `enableWindowsVM` - Pre-configured Windows VM container

### Platform-Specific Features (Must Match Hardware!)
- `enableNVIDIA` - NVIDIA drivers, CUDA support (**esnixi**)
- `enableAMDGPU` - AMD GPU with ROCm support (**macland**)
- `enableMacBookT2` - T2 chip, Touch Bar, fan control (**macland only**)

### Optional Tools (Low Impact)
- `enableMonitoringTools` - btop, iotop, iftop, strace
- `enableRemoteAccess` - FreeRDP, wlvncc for remote desktop
- `enableAudioEffects` - EasyEffects, LADSPA plugins
- `enableFonts` - Extended font packages

---

## 📊 Build Time Estimates by Configuration

| Configuration | Est. Build Time | Disk Usage | When to Use |
|--------------|-----------------|------------|-------------|
| Minimal Server | 5-10 min | ~8 GB | Headless servers, VPS |
| Basic Desktop | 15-20 min | ~25 GB | General desktop use |
| Developer | 20-30 min | ~35 GB | Software development |
| Gaming | 25-35 min | ~40 GB | Gaming desktops |
| AI/ML Workstation | 60-90 min | ~70+ GB | Machine learning work |
| Full Build (all enabled) | 90-180 min | ~100+ GB | Evaluation purposes only ⚠️ |

---

## 🔧 How to Modify Feature Flags

### Method 1: Direct Edit (Recommended for Beginners)
```bash
# Copy the feature flags file to your local config directory
cp ~/sources/nix-flakes-experimental/feature-flags.nix \
   ~/sources/nix-flakes-experimental/esnixi/feature-flags-local.nix

# Edit it with your preferred editor
nano ~/sources/nix-flakes-experimental/esnixi/feature-flags-local.nix

# Change the boolean values (true/false) for features you want to enable/disable

# Rebuild after editing
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi
```

### Method 2: Use Pre-made Templates
Create multiple configuration files for different use cases:
```bash
cd ~/sources/nix-flakes-experimental/esnixi

# Create templates for each scenario
cp feature-flags-local.nix feature-minimal.nix
cp feature-flags-local.nix feature-dev.nix
cp feature-flags-local.nix feature-gaming.nix
cp feature-flags-local.nix feature-ai.nix

# Edit each template with its specific configuration

# Use templates when rebuilding
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi \
  -I featureFlags=feature-minimal.nix
```

---

## ⚠️ Important Warnings & Tips

### Critical Warnings
1. **NEVER disable `enableCoreSystem`** - This will break your boot!
2. **Match platform flags to your hardware:**
   - NVIDIA GPU → `enableNVIDIA = true`, `enableAMDGPU = false`
   - AMD GPU/Mac T2 → `enableNVIDIA = false`, `enableAMDGPU = true`
3. **AI features are VERY heavy** - Only enable if actively using!
4. **Kubernetes adds significant build time** - Disable unless needed!
5. **Python + CUDA is HEAVY** - Consider disabling if not doing ML work

### Performance Tips
1. **Disable features you don't need right now** for faster builds
2. **Use caching** - After first full build, subsequent builds are much faster
3. **Build incrementally** - Start minimal, add features as needed
4. **Monitor disk space** - Full build can use 100+ GB

### Troubleshooting
- **Feature not working after change?** → Rebuild and verify systemd status
- **Build takes too long?** → Disable AI features and Kubernetes
- **Need to re-enable a feature?** → Just set flag to `true` and rebuild
- **Platform-specific issue?** → Check platform flags match your hardware

---

## 📚 Additional Resources

### Documentation Files
- `FEATURE_FLAGS_GUIDE.md` - Detailed guide with all features explained
- `FEATURE_COVERAGE_MAP.md` - Maps each feature to its controlling flag
- `QUICK_FLAG_REFERENCE.md` - Quick reference card for common configurations

### External Links
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Documentation](https://nix-community.github.io/home-manager/)
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Ollama Docs](https://github.com/ollama/ollama)
- [ComfyUI GitHub](https://github.com/comfyanonymous/ComfyUI)

---

## 🎯 Next Steps

1. **Choose your use case** from the configurations above
2. **Copy and edit feature flags** to match your needs
3. **Rebuild with:** `sudo nixos-rebuild switch --flake ...`
4. **Verify features are enabled** with: `systemctl list-unit-files | grep ...`
5. **Enjoy your optimized system!** 🚀

---

**Remember: Less is more! Disable features you don't need right now for faster builds. You can always re-enable them later when you need them!**
