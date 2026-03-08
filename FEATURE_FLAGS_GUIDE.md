# NixOS Experimental Configuration - Feature Flags Guide

## 🚀 Quick Start: Avoid Long Builds!

This configuration includes **feature flags** that let you selectively enable only what you need. By default, the build will include everything (for evaluation purposes). To speed up builds:

1. Open `feature-flags.nix`
2. Set features to `false` that you don't need right now
3. Rebuild with: `nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi`

---

## 📋 Feature Flag Reference

### ⚡ CORE SYSTEM (Keep Enabled)
```nix
enableCoreSystem = true;        # Essential system services, user setup, bootloader
```
**Impact:** LOW | **Always keep this enabled** - without it, the system won't boot!

---

### 🖥️ DESKTOP ENVIRONMENT
```nix
enableDesktopEnvironment = true;   # Hyprland window manager and Quickshell
enableToucheggGestures = true;      # Touchégg gesture support (for touchpads)
enableKeydRemapping = true;          # keyd keyboard remapping daemon
enableTheming = true;                # Custom cursors, GTK themes, appearance
```
**Impact:** LOW-MEDIUM | **Recommended for desktop users**

**Disable if:** Building a headless server or minimal system.

---

### 🎮 GAMING & ENTERTAINMENT
```nix
enableGaming = false;             # Steam, Protontricks, GameMode, Mangohud
enableVRSupport = false;          # ALVR, WiVRn for VR streaming
enableMediaPlayers = false;       # mpv, vlc, Spotify, Tidal-Hifi, etc.
```
**Impact:** MEDIUM | **Optional - only enable if you game or use media apps**

**Disable to save build time if:** You don't play games or stream video locally.

---

### 💻 DEVELOPMENT TOOLS (Can Be Very Heavy!)
```nix
enableDevelopmentTools = false;   # VSCode, JetBrains, compilers, languages

# Sub-categories:
enableVSCode = true;              # VSCode with extensions
enableJetBrains = true;           # JetBrains Toolbox
enablePythonDev = true;           # Python + CUDA support (HEAVY!)
enableNodeJS = true;              # Node.js and npm packages
enableJava = true;                # OpenJDK
enableCMakeBuildTools = true;     # CMake, Meson, Ninja
enableKubernetes = false;         # k3s, Helm, Kustomize (HEAVY!)
```
**Impact:** HIGH | **Only enable what you actually use!**

**Quick Start for Developers:**
- Just need Python? Set `enablePythonDev = true`, others to `false`
- Only VSCode? Set `enableVSCode = true`, disable JetBrains and compilers
- Need Kubernetes? Enable `enableKubernetes = true` (will take longer)

---

### 🤖 AI & MACHINE LEARNING (VERY HEAVY!)
```nix
enableAIService = false;          # Ollama local LLM server

# Sub-categories:
enableOllama = true;              # Local LLM inference with CUDA/ROCm (VERY HEAVY!)
enableComfyUI = true;             # ComfyUI image generation service (HEAVY!)
enableMCP = true;                 # Model Context Protocol servers (MODERATE)
```
**Impact:** VERY HIGH | **Only enable if you're actively using AI tools!**

**Quick Start for AI Users:**
- Just want Ollama? Set `enableOllama = true`, others to `false`
- Need ComfyUI? Enable `enableComfyUI = true` (will download CUDA dependencies)
- Want MCP servers? Enable `enableMCP = true`

---

### 🖥️ VIRTUALIZATION & CONTAINERS
```nix
enableVirtualization = false;     # Docker, QEMU/KVM, libvirt

# Sub-categories:
enableDocker = true;              # Docker with NVIDIA support
enableQEMU = true;                # QEMU/KVM virtualization
enableWindowsVM = false;          # Pre-configured Windows VM container
```
**Impact:** MEDIUM | **Optional - only enable if you need containers/VMs**

---

### 📊 MONITORING & UTILITIES
```nix
enableMonitoringTools = false;    # btop, iotop, iftop, strace, etc.
enableRemoteAccess = false;       # FreeRDP, wlvncc for remote desktop
```
**Impact:** LOW | **Optional - useful but not essential**

---

### 🔊 AUDIO & SOUND
```nix
enableAudioEffects = true;        # EasyEffects, LADSPA plugins
enableMacBookT2Audio = false;     # MacBook T2-specific audio processing (macland only)
```
**Impact:** LOW | **Recommended for desktop users**

---

### 🌍 PLATFORM-SPECIFIC FEATURES
```nix
# NVIDIA features (esnixi platform):
enableNVIDIA = true;              # NVIDIA drivers, CUDA support

# AMD/ROCm features (macland platform):
enableAMDGPU = false;             # AMD GPU with ROCm support

# MacBook T2 specific:
enableMacBookT2 = false;          # T2 chip, Touch Bar, fan control (macland only)
```
**Impact:** MEDIUM-HIGH | **Select based on your hardware!**

---

### 🔐 SECURITY & PRIVACY
```nix
enableSecurityFeatures = true;    # Firewall, SOPS secrets management
enableBluetooth = true;           # Bluetooth support with Blueman
```
**Impact:** LOW | **Recommended to keep enabled**

---

## 🎯 Recommended Configurations by Use Case

### Minimal Server (Fastest Build)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = false;
enableGaming = false;
enableDevelopmentTools = false;
enableAIService = false;
enableVirtualization = false;
enableMonitoringTools = true;   # Optional but useful
enableSecurityFeatures = true;
```

### Developer Desktop (Balanced)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableGaming = false;           # Disable if you don't game
enableDevelopmentTools = true;  # Enable this!
enableVSCode = true;
enablePythonDev = true;
enableKubernetes = false;       # Disable unless needed

enableAIService = false;        # Disable if not using AI
enableVirtualization = true;    # Optional but useful
```

### Gaming Desktop (Full Experience)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableGaming = true;            # Enable this!
enableVRSupport = false;        # Only if you have VR headset
enableMediaPlayers = true;

enableDevelopmentTools = true;  # Optional but useful
enableAIService = false;        # Disable to save build time
```

### AI/ML Workstation (Maximum Features)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableGaming = false;           # Can disable if you prioritize AI
enableDevelopmentTools = true;  # Essential for ML work
enablePythonDev = true;         # Essential!

enableAIService = true;         # Enable this!
enableOllama = true;            # Essential!
enableComfyUI = true;           # For image generation work
enableMCP = true;               # For AI assistant integrations

enableVirtualization = false;   # Can disable if disk space is tight
```

### MacBook T2 (Apple Hardware)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableAMDGPU = true;            # Enable AMD support for T2 Macs
enableMacBookT2 = true;         # Enable T2-specific features
enableNVIDIA = false;           # Disable NVIDIA (not applicable)

enableDevelopmentTools = true;  # Optional but useful
enableAIService = false;        # ROCm support is experimental on T2
```

---

## ⚡ Build Time Estimates

| Configuration | Est. Build Time | Disk Usage |
|--------------|-----------------|------------|
| Minimal Server | ~5-10 min | ~8 GB |
| Developer (balanced) | ~15-30 min | ~25 GB |
| Gaming Desktop | ~20-40 min | ~35 GB |
| AI/ML Workstation | ~60-120 min | ~70+ GB |
| Full Build (all enabled) | ~90-180 min | ~100+ GB |

---

## 🔧 How to Use Feature Flags

### Step 1: Edit the Flag File
```bash
nano ~/sources/nix-flakes-experimental/feature-flags.nix
```

### Step 2: Set Your Desired Features
Change the boolean values (`true`/`false`) based on your needs.

### Step 3: Rebuild the System
```bash
# For esnixi (baremetal x86_64)
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi

# For macland (MacBook T2)
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#macland
```

### Step 4: Verify the Build
Check which features were actually enabled:
```bash
systemctl list-unit-files | grep -E '(hyprland|steam|ollama|docker)'
```

---

## 🚨 Important Notes

1. **Never disable `enableCoreSystem`** - This will break your boot!

2. **Platform-specific flags** must match your hardware:
   - NVIDIA GPUs → `enableNVIDIA = true`, `enableAMDGPU = false`
   - AMD GPUs → `enableNVIDIA = false`, `enableAMDGPU = true`
   - MacBook T2 → `enableMacBookT2 = true`, platform-specific modules

3. **AI features are heavy** - Only enable if you're actively using them!

4. **Development tools can be cached** - After first build, subsequent builds are faster due to Nix caching.

5. **NVIDIA CUDA dependencies** add significant build time and disk usage.

6. **ComfyUI downloads models** on first run - have stable internet connection ready.

---

## 🔄 Switching Between Configurations

You can create multiple configuration files for different use cases:

```bash
# Create separate config files for each scenario
cp feature-flags.nix feature-flags-minimal.nix
cp feature-flags.nix feature-flags-dev.nix
cp feature-flags.nix feature-flags-gaming.nix
cp feature-flags.nix feature-flags-ai.nix
```

Then rebuild with different flags:
```bash
# Use minimal config for server builds
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi \
  -I featureFlags=feature-flags-minimal.nix
```

---

## 📞 Troubleshooting

### Build Takes Too Long?
1. Disable `enableAIService` and related AI features
2. Disable `enableKubernetes` if not needed
3. Reduce `enableDevelopmentTools` to only what you need

### Feature Not Working After Change?
1. Check the feature flag is set correctly in `feature-flags.nix`
2. Rebuild: `sudo nixos-rebuild switch --flake ...`
3. Verify systemd service status: `systemctl status <service-name>`

### Need to Re-enable a Feature?
Simply change the value from `false` to `true` and rebuild. Nix will add the packages automatically.

---

## 📚 Additional Resources

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Documentation](https://nix-community.github.io/home-manager/)
- [Hyprland Wiki](https://wiki.hyprland.org/)
- [Ollama Docs](https://github.com/ollama/ollama)
- [ComfyUI GitHub](https://github.com/comfyanonymous/ComfyUI)

---

## 🎯 Quick Reference Card

```
CORE:      enableCoreSystem = true        # ALWAYS!

DESKTOP:   enableDesktopEnvironment = true    (recommended for desktops)

GAMING:    enableGaming = false               (optional)

DEV TOOLS: enableDevelopmentTools = false     (enable only what you need!)
           ├─ enableVSCode = true
           ├─ enablePythonDev = true
           └─ enableKubernetes = false         (heavy!)

AI/ML:     enableAIService = false            (VERY HEAVY - optional!)
           ├─ enableOllama = true
           ├─ enableComfyUI = true
           └─ enableMCP = true

VIRTUAL:   enableVirtualization = false       (optional)
           ├─ enableDocker = true
           └─ enableWindowsVM = false

PLATFORM:  enableNVIDIA = true                (match your GPU!)
           enableAMDGPU = false               (or AMD/ROCm for Mac T2)
           enableMacBookT2 = false            (for Apple hardware only)
```

---

**Happy building! 🚀** Remember to disable features you don't need right now to keep build times manageable. You can always re-enable them later when you need them.
