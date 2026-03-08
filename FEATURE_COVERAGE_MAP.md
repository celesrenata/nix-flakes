# Feature Coverage Map - What Each Flag Controls

This document maps every feature from the original configuration to its corresponding feature flag, so you know exactly what gets enabled/disabled when you toggle a switch.

---

## 📊 Feature-to-Flag Mapping Table

| Original Feature | Description | Flag Control | Build Impact |
|-----------------|-------------|--------------|--------------|
| **CORE FEATURES** | | | |
| nixpkgs.hostPlatform | NixOS platform target | `enableCoreSystem` | LOW |
| nix.settings.experimental-features | Flakes and nix-command | `enableCoreSystem` | NONE |
| time.timeZone | System timezone | `enableCoreSystem` | NONE |
| i18n.defaultLocale | Default locale | `enableCoreSystem` | NONE |
| users.users.celes | User account setup | `enableCoreSystem` | NONE |
| boot.loader.systemd-boot | Bootloader config | `enableCoreSystem` | LOW |
| boot.plymouth.enable | Splash screen | `enableCoreSystem` | LOW |
| security.pam.loginLimits | PAM limits | `enableCoreSystem` | NONE |
| **DESKTOP ENVIRONMENT** | | | |
| services.xserver.enable | X11 server | `enableDesktopEnvironment` | MEDIUM |
| services.displayManager.gdm | GDM display manager | `enableDesktopEnvironment` | LOW-MEDIUM |
| programs.hyprland.enable | Hyprland window manager | `enableDesktopEnvironment` | HIGH |
| services.touchegg.enable | Touchégg gesture system | `enableToucheggGestures` | LOW |
| services.keyd.enable | keyd keyboard remapping | `enableKeydRemapping` | LOW |
| fonts.packages | Font packages | `enableFonts` | MEDIUM |
| programs.fish.enable | Fish shell | Always enabled | NONE |
| **GAMING & ENTERTAINMENT** | | | |
| programs.steam.enable | Steam client | `enableGaming` | HIGH |
| programs.gamemode.enable | GameMode daemon | `enableGaming` | LOW |
| programs.alvr.enable | ALVR VR streaming | `enableVRSupport` | MEDIUM |
| services.wivrn.enable | WiVRn VR streaming | `enableVRSupport` | MEDIUM |
| programs.steam.extraPackages | Steam compatibility packages | `enableGaming` | MEDIUM |
| mpv, vlc, spotify, tidal-hifi | Media players | `enableMediaPlayers` | LOW-MEDIUM |
| grim, slurp, wf-recorder | Screenshot/record tools | Included in core | NONE |
| **DEVELOPMENT TOOLS** | | | |
| programs.git.enable | Git version control | `enableGitLFS` | LOW |
| programs.git.lfs.enable | Git LFS support | `enableGitLFS` | LOW |
| programs.vscode.enable | VSCode IDE | `enableDevelopmentTools && enableVSCode` | HIGH |
| programs.jetbrains-toolbox.enable | JetBrains Toolbox | `enableDevelopmentTools && enableJetBrains` | MEDIUM |
| python312.withPackages (torch, etc.) | Python + CUDA packages | `enableDevelopmentTools && enablePythonDev` | VERY HIGH |
| nodejs_20 | Node.js runtime | `enableDevelopmentTools && enableNodeJS` | LOW-MEDIUM |
| programs.java.enable | OpenJDK support | `enableDevelopmentTools && enableJava` | MEDIUM |
| cmake, meson, ninja | Build tools | `enableDevelopmentTools && enableCMakeBuildTools` | LOW-MEDIUM |
| k3s, helmfile, kustomize | Kubernetes tools | `enableDevelopmentTools && enableKubernetes` | VERY HIGH |
| **AI & MACHINE LEARNING** | | | |
| services.ollama.enable | Ollama LLM server | `enableAIService && enableOllama` | VERY HIGH |
| ollama environment variables | Ollama configuration | `enableAIService && enableOllama` | NONE |
| /opt/ollama/models directory | Model storage setup | `enableAIService && enableOllama` | NONE |
| pkgs.comfyui | ComfyUI package | `enableComfyUI` | VERY HIGH |
| MCP servers (browser, DALL-E, ChatGPT) | AI assistant integrations | `enableMCP` | MEDIUM |
| **VIRTUALIZATION** | | | |
| virtualisation.docker.enable | Docker daemon | `enableVirtualization && enableDocker` | HIGH |
| virtualisation.libvirtd.enable | libvirt/QEMU support | `enableVirtualization && enableQEMU` | HIGH |
| programs.virt-manager.enable | virt-manager GUI | `enableVirtualization && enableQEMU` | LOW-MEDIUM |
| windows VM container | Pre-configured Windows VM | `enableWindowsVM` | VERY HIGH (disk) |
| boot.kernelModules kvm-intel/amd | KVM kernel modules | `enableVirtualization && enableQEMU` | NONE |
| **MONITORING & UTILITIES** | | | |
| btop, iotop, iftop | System monitoring tools | `enableMonitoringTools` | LOW-MEDIUM |
| strace, ltrace, lsof | Debugging utilities | `enableMonitoringTools` | LOW-MEDIUM |
| lm_sensors, pciutils, usbutils | Hardware detection | `enableMonitoringTools` | NONE |
| freerdp, wayvnc | Remote desktop tools | `enableRemoteAccess` | MEDIUM |
| **AUDIO & SOUND** | | | |
| services.pipewire.enable | PipeWire audio server | Always enabled (core) | LOW-MEDIUM |
| services.easyeffects.enable | EasyEffects audio effects | `enableAudioEffects` | LOW |
| LADSPA plugins, Calf, LSP | Audio processing plugins | `enableAudioEffects` | MEDIUM |
| MacBook T2 DSP audio config | T2-specific sound processing | `enableMacBookT2Audio` (macland only) | MEDIUM |
| **PLATFORM-SPECIFIC** | | | |
| hardware.nvidia.enable | NVIDIA drivers support | `enableNVIDIA` | HIGH |
| services.xserver.videoDrivers = ["nvidia"] | NVDIA display driver | `enableNVIDIA` | HIGH |
| boot.kernelModules nvidia | NVIDIA kernel modules | `enableNVIDIA` | NONE |
| cudaPackages.cudatoolkit | CUDA toolkit support | `enableNVIDIA && enableAIService` | VERY HIGH |
| hardware.nvidia.prime | AMD GPU prime support | `enableAMDGPU` (macland) | MEDIUM |
| rocmSupport = true | ROCm AMD compute support | `enableAMDGPU` (macland) | MEDIUM |
| services.hardware.bolt.enable | Thunderbolt controller | `enableMacBookT2` (T2 only) | LOW |
| T2 fan control daemon | t2fanrd service | `enableMacBookT2` (T2 only) | NONE |
| **SECURITY & PRIVACY** | | | |
| networking.firewall.enable | Firewall configuration | `enableSecurityFeatures` | MEDIUM |
| hardware.bluetooth.enable | Bluetooth support | `enableBluetooth` | LOW-MEDIUM |
| services.blueman.enable | Blueman GUI for BT | `enableBluetooth` | LOW |
| sops-nix.nixosModules.sops | SOPS secrets management | `enableSecurityFeatures` | MEDIUM |
| **OPTIONAL TOOLS** | | | |
| wl-clipboard, cliphist | Wayland clipboard tools | Always included | NONE |
| hyprpicker, wtype, ydotool | Wayland utilities | Included in core | LOW |
| fuzzel, wofi | Application launchers | `enableOptionalTools` | LOW-MEDIUM |

---

## 🔍 Detailed Feature Breakdown by Category

### 🖥️ Desktop Environment Features (Enabled when `enableDesktopEnvironment = true`)

**Hyprland Window Manager:**
- Custom keybindings with modifier variables ($Primary, $Secondary, etc.)
- Dwindle and Master layout support
- Touchpad configuration (natural scroll, tap-to-click)
- Gestures (3-finger swipe, pinch)
- Animations with custom bezier curves
- Workspace management with special workspaces
- Quickshell integration

**Quickshell Desktop Shell:**
- Custom widgets and modules
- Color generation from wallpapers
- OSD display for volume/brightness control
- Media controls widget
- Settings panel integration
- Cheatsheet toggle
- Sidebar left/right toggles
- Overview toggle

**Touchégg Gesture System:**
- 3-finger pinch in: Close window
- 2-finger tap: Right click
- 3-finger click: Middle click
- 4-finger pinch in/out: Fullscreen modes
- 3-finger swipe up/down: Overview toggles
- 4-finger swipe left/right/up/down: Window movement

**keyd Keyboard Remapping:**
- Mac-style keybindings (Control = Meta, Meta = Control)
- Layer switching for control and meta keys
- Custom key mappings specific to MacBook layout

---

### 🎮 Gaming Features (Enabled when `enableGaming = true`)

**Steam Integration:**
- Steam client with Protontricks support
- GameMode daemon for performance optimization
- Mangohud FPS overlay
- Gamescope session support
- Remote Play firewall rules
- Dedicated Server firewall rules
- Extra compatibility packages: mesa-demos, nss, xorg.libxkbfile

**VR Support (enableVRSupport):**
- ALVR for VR streaming
- WiVRn with custom configuration
- OpenXR runtime setup
- FFmpeg profile constants

**Media Players:**
- mpv video player
- VLC media player
- Spotify client
- Tidal-Hifi high-fidelity streaming
- Discord (Vesktop for Wayland)
- Plex Desktop
- Jellyfin Media Player

---

### 💻 Development Tools (Enabled when `enableDevelopmentTools = true`)

**IDEs:**
- VSCode with Nix backend and extensions
- JetBrains Toolbox for IDE suite management
- Sublime Text alias
- Code alias

**Version Control & Languages:**
- Git with LFS support
- Python 3.12 with CUDA packages (torch, torchvision, torchaudio)
- Node.js 20
- OpenJDK
- TypeScript
- CMake, Meson, Ninja build tools

**Kubernetes Tools:**
- k3s lightweight Kubernetes
- Helm with wrapper
- Helmfile for declarative management
- Kustomize
- Kompose
- Kubevirt
- Krew (unstable)

---

### 🤖 AI/ML Features (Enabled when `enableAIService = true`)

**Ollama Local LLM Server:**
- CUDA acceleration (NVIDIA) or ROCm (AMD) support
- Model storage in `/opt/ollama/models`
- Qwen3:30b model configuration
- Environment variables for optimization
- Service with proper user/group permissions

**ComfyUI AI Image Generation:**
- Graph/node-based interface
- Custom package with dependencies
- Virtual environment management
- Server on port 8188

**Model Context Protocol Servers:**
- Browser automation via Playwright
- DALL-E image generation via OpenAI API
- ChatGPT conversation API
- Amazon Q CLI integration
- Kiro CLI integration

---

### 🖥️ Virtualization Features (Enabled when `enableVirtualization = true`)

**Docker:**
- NVIDIA runtime support
- Btrfs storage driver
- Bridge networking
- Data root in `/home/docker`

**QEMU/KVM:**
- libvirt for VM management
- virt-manager GUI
- KVM kernel modules with nested virtualization
- IOMMU for GPU passthrough
- TPM emulation for Windows 11
- virtio-win for Windows VMs

**Windows VM Container:**
- Dockurr/windows container
- Windows 11 configuration
- USB passthrough support
- Port forwarding (8006 SPICE, 3389 RDP)

---

### 🔊 Audio Features (Enabled when `enableAudioEffects = true`)

**PipeWire Audio System:**
- ALSA compatibility with 32-bit support
- PulseAudio compatibility layer
- WirePlumber session management
- JACK support with loopback device

**Audio Effects Processing:**
- LADSPA plugins for audio processing
- Calf plugins suite
- LSP plugins suite
- EasyEffects advanced processing
- Microphone boost (200%)
- Noise suppression (RNNoise)
- Compressor and Limiter
- Bass enhancer
- MacBook T2 DSP convolver tuning

---

### 🔐 Security Features (Enabled when `enableSecurityFeatures = true`)

**Firewall Configuration:**
- Port-specific rules for gaming, VR, AI services
- Bridge traffic allowed
- NetworkManager firewall integration

**Secrets Management:**
- SOPS-nix encrypted secrets storage
- GitHub token management
- OpenAI API token management
- Home certificate management
- SSH host key backup

**Bluetooth Security:**
- Hardware firmware support (Broadcom)
- Power management enabled
- Blueman GUI for Bluetooth management

---

### 🌍 Platform-Specific Features

**NVIDIA Support (enableNVIDIA = true):**
- NVIDIA kernel packages with custom version (580.105.08)
- 6.16 compatibility patches
- CUDA acceleration support
- Power management enabled
- Force full composition pipeline
- NVIDIA settings GUI

**AMD/ROCm Support (enableAMDGPU = true):**
- AMD GPU drivers (RADV for Vulkan)
- ROCm compute support
- Prime sync between integrated and discrete GPUs
- HSA override GFX version for T2 Macs

**MacBook T2 Features (enableMacBookT2 = true, macland only):**
- Thunderbolt controller (bolt service)
- T2 fan control daemon (t2fanrd)
- T2 suspend fix for sleep/wake cycles
- Apple BCE firmware support
- Touch Bar support (tiny-dfr)

---

## ⚠️ Dependencies Between Features

Some features depend on others being enabled:

| Feature | Depends On | Reason |
|---------|------------|--------|
| `enableOllama` with CUDA | `enableNVIDIA = true` | CUDA requires NVIDIA drivers |
| `enableComfyUI` | `enablePythonDev` | ComfyUI uses Python packages |
| `enableMCP` | `enableDevelopmentTools` | MCP servers need development tools |
| `enableVirtualization && enableWindowsVM` | `enableDocker` | Windows VM is a Docker container |
| `enableAMDGPU` on T2 Macs | `enableMacBookT2 = true` | T2 requires specific GPU config |

---

## 📈 Build Time Impact by Feature Group

| Feature Group | Estimated Additional Build Time | Disk Usage Increase |
|--------------|---------------------------------|---------------------|
| Core System (always on) | Base time | ~8 GB |
| Desktop Environment | +5-10 min | +2 GB |
| Gaming Features | +10-15 min | +8 GB |
| Development Tools | +30-60 min | +20 GB |
| AI/ML Services | +60-90 min | +40+ GB |
| Virtualization | +10-20 min | +15 GB |
| Monitoring Tools | +2-5 min | +1 GB |
| Audio Effects | +3-8 min | +3 GB |
| Platform Specific | +5-15 min | +5 GB |

---

## 🎯 Quick Decision Tree for Feature Flags

```
Do you need a desktop GUI?
├─ YES → enableDesktopEnvironment = true
└─ NO → enableDesktopEnvironment = false (headless server)

Are you a gamer?
├─ YES → enableGaming = true, enableMediaPlayers = true
└─ NO → enableGaming = false

Do you need AI/ML capabilities?
├─ YES → enableAIService = true, enableOllama = true
└─ NO → disable all AI features for faster builds

Are you a developer?
├─ Python only → enablePythonDev = true, others false
├─ Full stack → enableDevelopmentTools = true with all sub-flags
└─ Not needed → disable entire development tools section

Do you need virtualization/containers?
├─ YES → enableVirtualization = true
└─ NO → keep disabled for faster builds

What GPU do you have?
├─ NVIDIA → enableNVIDIA = true, enableAMDGPU = false
├─ AMD → enableNVIDIA = false, enableAMDGPU = true
└─ MacBook T2 → enableMacBookT2 = true (platform-specific)
```

---

**This map helps you understand exactly what each feature flag controls. Use it to make informed decisions about which features to enable based on your specific needs!**
