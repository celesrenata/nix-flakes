# Feature Flags Quick Reference Card

## 🎯 Core Features (ALWAYS ENABLED)
These features cannot be disabled without breaking core functionality:
- `enableCoreSystem` - Essential system services, user setup, bootloader
- `nixpkgs.hostPlatform` - x86_64-linux platform setting
- `users.users.celes` - User account configuration

---

## 🖥️ Desktop Environment Features

| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| Hyprland + Quickshell | `enableDesktopEnvironment` | LOW | Window manager and desktop shell |
| Touchégg Gestures | `enableToucheggGestures` | LOW | Touchpad gesture support |
| Keyd Remapping | `enableKeydRemapping` | LOW | Keyboard remapping daemon |
| Custom Theming | `enableTheming` | LOW | Cursors, GTK themes, appearance |

**Recommended:** Keep all enabled for desktop experience.

---

## 🎮 Gaming & Entertainment Features

| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| Steam + Proton | `enableGaming` | MODERATE | Gaming platform with compatibility layer |
| VR Support | `enableVRSupport` | LOW-MODERATE | ALVR and WiVRn for virtual reality |
| Media Players | `enableMediaPlayers` | LOW | mpv, vlc, Spotify, Tidal-Hifi |

**Recommended:** Enable if you game or consume media.

---

## 💻 Development Tools Features (**HEAVY!**)

| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| All Dev Tools | `enableDevelopmentTools` | HIGH | Master switch for development environment |
| VSCode | `enableVSCode` | MODERATE | Code editor with extensions |
| JetBrains | `enableJetBrains` | MODERATE | IDE toolbox (IntelliJ, PyCharm, etc.) |
| Python + CUDA | `enablePythonDev` | VERY HIGH | Python with ML libraries (torch, diffusers) |
| Node.js | `enableNodeJS` | LOW-MODERATE | JavaScript runtime and package manager |
| Java | `enableJava` | MODERATE | OpenJDK development environment |
| Build Tools | `enableCMakeBuildTools` | LOW | CMake, Meson, Ninja for compilation |
| Kubernetes | `enableKubernetes` | VERY HIGH | k3s, Helm, Kustomize for container orchestration |

**⚠️ Warning:** Enabling all dev tools will significantly increase build time (1-4 hours). Only enable what you need.

---

## 🤖 AI & Machine Learning Features (**VERY VERY HEAVY!**)

| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| AI Service | `enableAIService` | HIGH | Master switch for Ollama LLM server |
| Ollama | `enableOllama` | VERY HIGH | Local LLM inference with GPU acceleration (CUDA/ROCm) |
| ComfyUI | `enableComfyUI` | HIGH | AI image generation service |
| MCP Servers | `enableMCP` | MODERATE | Model Context Protocol servers for AI assistants |

**⚠️ Warning:** These features require substantial disk space (~50-100GB for models) and GPU resources. Only enable if you actively use AI/ML workloads.

---

## 🖥️ Virtualization & Containers Features

| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| All Virtualization | `enableVirtualization` | MODERATE | Master switch for container/virtual machine support |
| Docker | `enableDocker` | LOW-MODERATE | Container platform with NVIDIA support |
| QEMU/KVM | `enableQEMU` | LOW-MODERATE | Virtual machine hypervisor |
| Windows VM | `enableWindowsVM` | MODERATE | Pre-configured Windows 10/11 container for testing |

**Recommended:** Enable if you need containerization or VM testing capabilities.

---

## 🔧 System Tools Features

| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| Monitoring Tools | `enableMonitoringTools` | LOW | btop, iotop, iftop for system diagnostics |
| Remote Access | `enableRemoteAccess` | LOW | FreeRDP and WayVNC for remote desktop |

**Recommended:** Keep enabled for troubleshooting and remote management.

---

## 🎨 Audio Features

| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| Audio Effects | `enableAudioEffects` | LOW | EasyEffects with LADSPA plugins |
| MacBook T2 Audio | `enableMacBookT2Audio` | PLATFORM-SPECIFIC | Only for macland platform, disabled by default |

**Recommended:** Enable audio effects if you need advanced sound processing.

---

## 🔐 Platform-Specific Features

### NVIDIA (esnixi platform)
| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| NVIDIA Support | `enableNVIDIA` | MODERATE | Proprietary drivers and CUDA support |

**Required for:** AI/ML workloads requiring NVIDIA GPUs.

### AMD/ROCm (macland platform)
| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| AMD GPU + ROCm | `enableAMDGPU` | MODERATE | Open-source drivers with ROCm compute support |

**Required for:** MacBook T2 with integrated AMD graphics.

### MacBook T2 Specific
| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| T2 Chip Features | `enableMacBookT2` | PLATFORM-SPECIFIC | Touch Bar, fan control, T2 security chip support |

**Only for:** MacBook hardware with T2 chip. Disabled by default.

---

## 🔒 Security & Privacy Features

| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| Firewall + Secrets | `enableSecurityFeatures` | LOW | Firewall and SOPS encrypted secrets management |
| Bluetooth | `enableBluetooth` | LOW | Bluetooth support with Blueman manager |

**Recommended:** Keep security features enabled for production deployments.

---

## 🛠️ Optional Tools (Low Impact)

| Feature | Flag Name | Impact | Description |
|---------|-----------|--------|-------------|
| Optional Utilities | `enableOptionalTools` | LOW | Fuzzel, ydotool, wtype, gz utilities |
| Fonts | `enableFonts` | LOW-MODERATE | Extended font packages (Fira Code, Material Symbols) |
| Git LFS | `enableGitLFS` | LOW | Large file storage for Git repositories |

**Recommended:** Enable all for better user experience.

---

## 📊 Quick Configuration Examples

### Minimal Desktop (Fastest Build ~30 min)
```nix
{
  enableCoreSystem = true;
  enableDesktopEnvironment = true;
  enableTheming = true;
  # All other features disabled
}
```

### Developer Workstation (Balanced ~1-2 hours)
```nix
{
  enableCoreSystem = true;
  enableDesktopEnvironment = true;
  enableDevelopmentTools = true;
  enableVSCode = true;
  enablePythonDev = false;  # Disable heavy ML libraries
  enableKubernetes = false; # Only if needed
}
```

### AI/ML Research System (Slowest Build ~2-4 hours)
```nix
{
  enableCoreSystem = true;
  enableDesktopEnvironment = true;
  enableDevelopmentTools = true;
  enableAIService = true;
  enableOllama = true;
  enableComfyUI = true;
  enableMCP = true;
}
```

### Production Server (No GUI, Minimal)
```nix
{
  enableCoreSystem = true;
  enableDesktopEnvironment = false;
  enableVirtualization = true;
  enableDocker = true;
  enableMonitoringTools = true;
  # All other features disabled
}
```

---

## 🎯 Decision Tree for Feature Selection

1. **Do you need AI/ML capabilities?**
   - YES → Enable `enableAIService`, `enableOllama`, `enableComfyUI`
   - NO → Skip to step 2

2. **Are you a developer?**
   - YES → Enable `enableDevelopmentTools`, select specific tools (VSCode, Python, etc.)
   - NO → Skip to step 3

3. **Do you need virtualization/containers?**
   - YES → Enable `enableVirtualization` and sub-features (Docker, QEMU)
   - NO → Skip to step 4

4. **Do you game or consume media?**
   - YES → Enable `enableGaming`, `enableMediaPlayers`
   - NO → Keep disabled for minimal footprint

5. **Do you need remote access/monitoring?**
   - YES → Enable `enableRemoteAccess`, `enableMonitoringTools`
   - NO → Skip to step 6

6. **Security requirements?**
   - Production → Keep `enableSecurityFeatures = true` (firewall, SOPS)
   - Testing → Can disable for faster builds

---

## ⚠️ Important Notes

1. **Build Time Increases:** Each enabled feature adds compilation time. Plan accordingly.
2. **Disk Space:** Full configuration requires 50-100GB+ of disk space for packages and models.
3. **GPU Requirements:** AI/ML features require GPU with CUDA (NVIDIA) or ROCm (AMD) support.
4. **Platform-Specific:** Some flags only work on specific hardware (esnixi vs macland).
5. **Testing First:** Always test builds before production deployment using `quick-vm-test.sh`.

---

## 🔗 Related Documentation

- `FEATURE_FLAGS_GUIDE.md` - Detailed feature descriptions and use cases
- `CONFIGURATION.md` - Complete system configuration reference
- `VM_TESTING_COMPLETE.md` - QEMU testing procedures for safe validation
