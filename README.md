# nix-flakes — Personal NixOS System Configuration

Fully declarative NixOS system configuration for a baremetal workstation. Features a host matrix with togglable profile groups, an AI-native Hyprland desktop (via [end-4-flakes](https://github.com/celesrenata/end-4-flakes)), CUDA-accelerated AI/ML stack, gaming, virtualization, and development tools — all managed through a single `nixos-rebuild switch`.

**Platform:** Baremetal x86_64 NixOS (esnixi). T2/Mac support removed.

## Host Matrix & Application Groups

Hosts are defined declaratively with a hardware acceleration backend and a set of togglable feature groups:

```nix
hosts = {
  esnixi = {
    system = "x86_64-linux";
    backend = "cuda";          # "cuda" | "rocm" | "cpu"
    groups = {
      games = true;
      development = true;
      videoEditing = true;
      virtualization = true;
      ai = true;
    };
  };
};
```

### Profile Groups

| Group | What it provides |
|-------|-----------------|
| **games** | Steam + Proton GE + protontricks, gamemode, ALVR (wireless VR streaming), WiVRn, xpadneo (Xbox controller), Gamescope session, `/mnt/games` with proper ownership |
| **development** | GCC 13, CMake, Meson, Ninja, Node.js, Java, TypeScript, AWS CLI + CDK, k3s, Helm + plugins (secrets/diff/s3/git), helmfile, kustomize, kompose, kubevirt, krew, ccache, codex (AI coding agent), uv/pipx, nil (Nix LSP) |
| **videoEditing** | Kdenlive, ffmpeg-full, mkvtoolnix, darktable, Blender |
| **virtualization** | Docker (btrfs backend), QEMU/KVM + libvirtd + virt-manager, nested virtualization, IOMMU/GPU passthrough, Windows container (dockurr/windows with RDP + WinApps Office 365 integration), bridge/macvlan networking |
| **ai** | Ollama (CUDA, flash attention, 262K context, auto-loaded Qwen 3.6 models), vLLM (NVFP4 quantized serving on port 8000), Open WebUI (port 8776), CUDA toolkit, PyTorch + torchvision + torchaudio, transformers, diffusers, accelerate, HuggingFace model management, model directory ownership management |

### Overlay Groups

Each profile also selects package overlays:

| Group | Overlays applied |
|-------|-----------------|
| **common** | nixgl, dots-hyprland (quickshell patches), keyboard-visualizer, debugpy, comfyui, mkvtoolnix |
| **desktop** | materialyoucolor, end-4-dots, fuzzel-emoji, wofi-calc, dots-hyprland-dp3-filter |
| **development** | helmfile, jetbrains-toolbox, LaTeX, nix-static, MCP servers, inline-snapshot-fix |
| **gaming** | protontweaks, wivrn-fix |
| **ai** | vLLM, TensorRT, Ollama (GCC 13 build), xformers-bin, bitsandbytes |

### Disabling Groups

Set any group to `false` to remove its packages, services, and overlays entirely:

```nix
groups = {
  games = false;        # No Steam, Proton, ALVR, gamemode
  development = true;
  videoEditing = false;  # No Kdenlive, Blender
  virtualization = false; # No Docker, QEMU, Windows VM
  ai = false;           # No Ollama, vLLM, CUDA ML packages
};
```

### Configurable Paths

```nix
my.paths = {
  dockerData = "/var/lib/docker";
  ollamaHome = "/var/lib/ollama";
  ollamaModels = "/var/lib/ollama/models";
  vllmHome = "/var/lib/vllm";
  vllmModels = "/var/lib/vllm/models";
  buildScratch = "/var/tmp/nix-build";
};
```

## Desktop Environment

The desktop is powered by [end-4-flakes](https://github.com/celesrenata/end-4-flakes) — a heavily modified fork of end-4's dots-hyprland with AI/voice integration and deep Material You theming. Consumed as the `dots-hyprland` flake input.

### What the desktop provides

- **Material You theming** — Wallpaper colors propagate to foot terminal, fuzzel launcher, Qt apps, Hyprland borders, and RGB hardware. Dark/light mode with wallpaper variant auto-switching.
- **AI sidebar chat** — Multi-provider LLM support (OpenAI, Anthropic, Gemini, Mistral, OpenRouter, AWS Bedrock, Ollama). Streaming responses, context window tracking, multiple named sessions, `/compact` summarization.
- **Voice assistant** — Streaming dictation (WebSocket/chunked/batch), bidirectional voice conversations (Nova Sonic / OpenAI Realtime), TTS talkback (piper, espeak-ng, OpenAI), intent classification.
- **AI Action Palette** — Type `?` in the launcher for natural language → structured desktop actions with preview/apply/revert.
- **Context Lens** — `Super+Shift+A` for AI vision analysis of screen regions.
- **ii-desktop-mcp** — MCP server exposing desktop state (config, audio, network, systemd, clipboard, apps, screenshots, diagnostics) to AI clients.
- **Desktop Demo Driver** — Automated 30+ scene demo system via ydotool.
- **Bar** — Resources, media, workspaces (default/hefty), clock, utility buttons, battery, system tray, weather. Brightness scroll (left), volume scroll (right).
- **Sidebars** — Left: AI chat, providers, translator, anime. Right: quick toggles, notifications, volume mixer, calendar, todo.
- **Overview/Launcher** — Apps, math, commands, web search, clipboard, emoji, AI actions, launcher actions.

See the [end-4-flakes README](https://github.com/celesrenata/end-4-flakes) for full desktop feature documentation.

## Hardware & Platform (esnixi)

- **GPU** — NVIDIA (580 drivers, CUDA, NVENC/NVDEC)
- **Display** — Multi-monitor with DP-3 filtering, Hyte Y70 Touch-Infinite integration
- **Networking** — NetworkManager, Thunderbolt, Cloudflare WARP
- **Audio** — PipeWire with EasyEffects
- **Input** — Logitech dictation button filter (keyd → F20 → Quickshell dictation), touchegg gestures
- **RGB** — Wallpaper color sync to RGB hardware via custom gradient service
- **Monitoring** — System metrics collection
- **Remote desktop** — Sunshine streaming
- **LAN mouse** — Cross-machine mouse sharing

## Secrets Management

SOPS-nix for encrypted secrets:
- `secrets/secrets.yaml` encrypted with age keys
- Decrypted at runtime to `/run/secrets/`
- Used for: HuggingFace token (vLLM model access), GitHub token (flake fetching)
- Custom CA certificate (celestium-ca.crt) for internal services

## Structure

```
.
├── flake.nix                  # Host matrix, mkHost factory, overlay groups, inputs
├── configuration.nix          # Core system config (nix settings, nix-ld, locale, audio, fonts)
├── esnixi/                    # Platform-specific: hardware, boot, graphics, networking, services
│   ├── hardware-configuration.nix
│   ├── boot.nix               # GRUB bootloader
│   ├── graphics.nix           # NVIDIA 580 + CUDA
│   ├── networking.nix         # NetworkManager + firewall
│   ├── games.nix              # Steam, ALVR, WiVRn, gamemode
│   ├── virtualisation.nix     # Docker, QEMU/KVM, Windows VM
│   ├── hyte-touch.nix         # Hyte Y70 Touch-Infinite display
│   ├── monitoring.nix         # System metrics
│   ├── remote-desktop.nix     # Sunshine streaming
│   ├── thunderbolt.nix        # Thunderbolt security
│   ├── lan-mouse.nix          # Cross-machine mouse
│   ├── vllm-proxy.nix         # vLLM reverse proxy
│   ├── lvra.nix               # LVRA AI assistant
│   └── hyprland.nix           # HM: Hyprland keybinds, env, monitors
├── home/                      # Home Manager user configuration
│   ├── default.nix            # Entry point importing all HM modules
│   ├── desktop/
│   │   ├── hyprland.nix       # Hyprland session config
│   │   ├── quickshell.nix     # Quickshell (via dots-hyprland module)
│   │   ├── hypridle.nix       # Idle/lock/suspend cascade
│   │   ├── theming.nix        # GTK/Qt themes, cursors, icons
│   │   └── thunar.nix         # File manager
│   ├── programs/
│   │   ├── development.nix    # VSCode, Git, dev tools
│   │   ├── productivity.nix   # Browsers, LibreOffice, Obsidian
│   │   ├── media.nix          # OBS, players, Tidal, Spotify
│   │   ├── terminal.nix       # foot, kitty
│   │   ├── comfyui.nix        # AI image generation
│   │   ├── ii-desktop-mcp.nix # MCP server HM config
│   │   ├── mcp.nix            # MCP client configs
│   │   └── lvra.nix           # LVRA config
│   ├── shell/
│   │   ├── fish.nix           # Fish shell + plugins
│   │   ├── bash.nix           # Bash config
│   │   └── starship.nix       # Prompt
│   └── system/
│       ├── packages.nix       # User packages
│       ├── files.nix          # Dotfiles
│       ├── variables.nix      # Session variables
│       ├── rgb-gradient.nix   # RGB lighting service
│       └── hyte-touch.nix     # Hyte display user service
├── modules/
│   ├── profiles/
│   │   ├── options.nix        # Profile group option declarations
│   │   ├── ai.nix             # AI profile (Ollama, vLLM, CUDA)
│   │   ├── development.nix    # Dev profile (compilers, k8s, AWS)
│   │   └── video-editing.nix  # Video profile (Kdenlive, Blender)
│   ├── background-removal.nix
│   └── graphics-nvidia.nix
├── overlays/                  # 40+ package overlays grouped by category
├── patches/                   # Source patches (NVIDIA, Hyprland, AGS, keyd)
├── secrets/                   # SOPS encrypted secrets
├── scripts/                   # Helper scripts (RGB gradient, install scripts, migrations)
├── logi-dictation-filter.nix  # Logitech dictation button → keyd → Quickshell
└── remote-build.nix           # Distributed build configuration
```

## Flake Inputs

| Input | Purpose |
|-------|---------|
| `nixpkgs` | NixOS unstable (main channel) |
| `home-manager` | User environment management |
| `dots-hyprland` | end-4-flakes (AI desktop, theming, Quickshell modules) |
| `dots-hyprland-source` | Upstream fork (quickshell-locked branch, source files only) |
| `ii-desktop-mcp` | Desktop MCP server (Hyprland + Quickshell + system tools) |
| `hyte-touch-infinite-flakes` | Hyte Y70 Touch-Infinite display support |
| `nix-comfyui` | AI image generation (ComfyUI) |
| `onetrainer-flake` | Diffusion model training |
| `protontweaks` | Steam Proton compatibility tweaks |
| `sops-nix` | Encrypted secrets management |
| `nixgl` | OpenGL wrapper for Nix |
| `anyrun` | Application launcher |
| `niri` | Niri Wayland compositor (experimental) |
| `kiro-cli` | Kiro AI coding assistant CLI |
| `cline-cli` | Cline AI coding assistant CLI |
| `mermaid-rs-renderer` | Mermaid diagram renderer (pure Rust) |
| `nix-vscode-extensions` | VSCode extension packages |
| `ags` | Desktop shell widgets (gorsbart fork) |
| `dream2nix` | Language-specific package management |

## Usage

### Rebuild system
```bash
sudo nixos-rebuild switch --flake .#esnixi
```

### Update all inputs
```bash
nix flake update
```

### Update a single input
```bash
nix flake update dots-hyprland   # After pushing end-4-flakes changes
nix flake update ii-desktop-mcp  # After pushing hyprmcp changes
```

### Test without switching
```bash
sudo nixos-rebuild test --flake .#esnixi
```

## Key Keybinds

| Key | Action |
|-----|--------|
| `Super` (tap) | Overview / launcher |
| `Super+Return` | Terminal |
| `Super+A` | Left sidebar (AI chat) |
| `Super+N` | Right sidebar |
| `Super+/` | Cheatsheet |
| `Super+Shift+A` | Context Lens (AI vision) |
| `?` in launcher | AI Action Palette |
| `Ctrl+H` / dictation key | Voice dictation |
| `Ctrl+Super+Shift+D` | Dark / Light toggle |
| `Super+Alt+F10` | Desktop Demo Driver |
| `Super+Alt+F1` | VM passthrough mode |

## Credits

- [end-4](https://github.com/end-4) — dots-hyprland and illogical-impulse aesthetic
- [outfoxxed](https://github.com/outfoxxed) — Quickshell framework
- [Hyprland team](https://hyprland.org/) — Wayland compositor
- NixOS community — The declarative ecosystem

## License

MIT — See [LICENSE](LICENSE) for details.
