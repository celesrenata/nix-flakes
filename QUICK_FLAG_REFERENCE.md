# ⚡ Quick Feature Flag Reference Card

**Copy this to your clipboard and paste into `feature-flags.nix`!**

---

## 🎯 Minimal Server (Fastest Build - ~5 min)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = false;
enableGaming = false;
enableDevelopmentTools = false;
enableAIService = false;
enableVirtualization = false;
enableMonitoringTools = false;
enableSecurityFeatures = true;
enableBluetooth = true;
```

---

## 💻 Basic Developer Desktop (~15-20 min)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableToucheggGestures = true;
enableKeydRemapping = true;
enableTheming = true;

enableGaming = false;
enableVRSupport = false;
enableMediaPlayers = false;

enableDevelopmentTools = true;
enableVSCode = true;
enableJetBrains = true;
enablePythonDev = true;
enableNodeJS = true;
enableJava = true;
enableCMakeBuildTools = true;
enableKubernetes = false;  # Disable unless needed!

enableAIService = false;
enableVirtualization = true;
enableDocker = true;
enableQEMU = false;
```

---

## 🎮 Gaming Desktop (~25-35 min)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableToucheggGestures = true;
enableKeydRemapping = true;

enableGaming = true;          # Enable this!
enableVRSupport = false;      # Only if you have VR headset
enableMediaPlayers = true;    # For media consumption

enableDevelopmentTools = true;  # Optional but useful
enableVSCode = true;
enablePythonDev = false;        # Disable unless doing ML work
enableKubernetes = false;

enableAIService = false;
enableVirtualization = false;   # Can disable if disk space tight
```

---

## 🤖 AI/ML Workstation (~60-90 min)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableToucheggGestures = true;

enableGaming = false;           # Disable to prioritize AI resources
enableVRSupport = false;
enableMediaPlayers = false;

enableDevelopmentTools = true;  # Essential for ML work!
enablePythonDev = true;         # Essential!
enableNodeJS = true;
enableJava = true;
enableKubernetes = false;       # Can disable if not needed

enableAIService = true;         # Enable this!
enableOllama = true;            # Essential for local LLMs!
enableComfyUI = true;           # For image generation work
enableMCP = true;               # For AI assistant integrations

enableVirtualization = false;   # Can disable if disk space tight
```

---

## 🍎 MacBook T2 (Apple Hardware) (~30-45 min)
```nix
enableCoreSystem = true;
enableDesktopEnvironment = true;
enableToucheggGestures = true;
enableKeydRemapping = true;
enableTheming = true;

enableAMDGPU = true;            # Enable AMD support for T2 Macs
enableNVIDIA = false;           # Disable NVIDIA (not applicable)
enableMacBookT2 = true;         # Enable T2-specific features

enableGaming = false;
enableVRSupport = false;
enableMediaPlayers = true;

enableDevelopmentTools = true;
enablePythonDev = false;        # ROCm on T2 is experimental
enableKubernetes = false;

enableAIService = false;        # ROCm support is experimental on T2
enableVirtualization = true;
```

---

## 🔧 Custom Configuration Formula

**Start with this template and adjust:**

```nix
# CORE (ALWAYS TRUE)
enableCoreSystem = true;
enableSecurityFeatures = true;
enableBluetooth = true;

# DESKTOP (TRUE for GUI, FALSE for headless server)
enableDesktopEnvironment = true;  # or false
enableToucheggGestures = true;    # Optional but nice
enableKeydRemapping = true;       # Optional but nice

# GAMING (FALSE unless you game!)
enableGaming = false;             # Set to true if gaming
enableVRSupport = false;          # Only enable with VR headset
enableMediaPlayers = true;        # Recommended for most users

# DEVELOPMENT (ENABLE ONLY WHAT YOU NEED!)
enableDevelopmentTools = false;   # Set to true if developing
enableVSCode = true;              # IDE choice 1
enableJetBrains = true;           # IDE choice 2
enablePythonDev = true;           # Python + CUDA (HEAVY!)
enableNodeJS = true;              # Node.js
enableJava = true;                # Java
enableCMakeBuildTools = true;     # Build tools
enableKubernetes = false;         # Kubernetes (VERY HEAVY!)

# AI/ML (DISABLE UNLESS ACTIVELY USING!)
enableAIService = false;          # Set to true if using local LLMs
enableOllama = false;             # Local LLM server (VERY HEAVY!)
enableComfyUI = false;            # Image generation (HEAVY!)
enableMCP = false;                # AI assistant integrations

# VIRTUALIZATION (OPTIONAL)
enableVirtualization = false;     # Set to true if needing containers/VMs
enableDocker = true;              # Docker support
enableQEMU = true;                # QEMU/KVM support
enableWindowsVM = false;          # Pre-configured Windows VM

# PLATFORM-SPECIFIC (MUST MATCH YOUR HARDWARE!)
enableNVIDIA = true;              # Set to false for AMD/Mac
enableAMDGPU = false;             # Set to true for AMD/Mac T2
enableMacBookT2 = false;          # Only for Apple hardware with T2

# OPTIONAL TOOLS (MOSTLY LOW IMPACT)
enableMonitoringTools = false;    # System monitoring tools
enableRemoteAccess = false;       # RDP/vnc tools
enableAudioEffects = true;        # Audio processing plugins
enableFonts = true;               # Extended fonts
```

---

## 📊 Build Time Reference

| Configuration | Build Time | Disk Usage | Best For |
|--------------|------------|------------|----------|
| Minimal Server | 5-10 min | ~8 GB | Headless servers, VPS |
| Basic Desktop | 15-20 min | ~25 GB | General desktop use |
| Developer | 20-30 min | ~35 GB | Software development |
| Gaming | 25-35 min | ~40 GB | Gaming desktops |
| AI/ML Workstation | 60-90 min | ~70+ GB | Machine learning work |
| Full Build | 90-180 min | ~100+ GB | Evaluation purposes only |

---

## ⚠️ Critical Warnings

1. **NEVER disable `enableCoreSystem`** - System won't boot!
2. **Match platform flags to your hardware:**
   - NVIDIA GPU → `enableNVIDIA = true`, `enableAMDGPU = false`
   - AMD GPU/Mac T2 → `enableNVIDIA = false`, `enableAMDGPU = true`
3. **AI features are VERY heavy** - Only enable if actively using!
4. **Kubernetes adds significant build time** - Disable unless needed!
5. **Python + CUDA is HEAVY** - Consider disabling if not doing ML work

---

## 🔄 Quick Toggle Commands

```bash
# Check current feature status (after rebuild)
systemctl list-unit-files | grep -E '(hyprland|steam|ollama|docker)'

# Rebuild with new features
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi

# Test build first (faster, no reboot)
sudo nixos-rebuild build --flake ~/sources/nix-flakes-experimental#esnixi

# Dry-run to see what will change
sudo nixos-rebuild switch --flake ~/sources/nix-flakes-experimental#esnixi --dry-run
```

---

**Remember: Less is more! Disable features you don't need right now for faster builds. You can always re-enable them later!**
