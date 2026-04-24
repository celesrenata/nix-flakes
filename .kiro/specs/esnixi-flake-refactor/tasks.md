# Implementation Plan: esnixi-flake-refactor

## Overview

Refactor the NixOS flake configuration from a monolithic, CUDA-polluted package set into a cleanly separated architecture with distinct package sets, grouped overlays, a profile module system, helper functions, and a declarative host matrix. The implementation follows a two-phase rollout: Phase 1 covers flake/profile refactoring (Requirements 1–7, 11), Phase 2 covers storage layout and service migration (Requirements 8–10). Each task implements the user's provided Nix code for the target files.

## Tasks

- [x] 1. Create overlay group registry
  - [x] 1.1 Create `overlays/default.nix` with grouped overlay sets
    - Define the `{ inputs }:` function that returns an attribute set with keys: `common`, `desktop`, `development`, `gaming`, `ai`
    - `common`: nixgl, nix-openclaw (dots-hyprland), dots-hyprland overlay, keyboard-visualizer, debugpy
    - `desktop`: materialyoucolor, end-4-dots, fuzzel-emoji, wofi-calc, dots-hyprland-dp3-filter
    - `development`: helmfile, jetbrains-toolbox, latex, lmstudio (nix-static), nix-static
    - `gaming`: protontweaks
    - `ai`: comfyui, vllm, tensorrt, ollama (with GCC 13), xformers-bin, bitsandbytes
    - Each group is a list of overlay functions imported from the existing `overlays/*.nix` files
    - Pass `inputs` through to overlays that need it (e.g., `dots-hyprland-dp3-filter`, `dots-hyprland`)
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 11.3_

- [x] 2. Create profile module system
  - [x] 2.1 Create `modules/profiles/options.nix` with all option declarations
    - Declare `my.profiles.games.enable`, `my.profiles.development.enable`, `my.profiles.videoEditing.enable`, `my.profiles.virtualization.enable`, `my.profiles.ai.enable` as boolean options defaulting to `false`
    - Declare `my.acceleration.backend` as an enum option with values `"cuda"`, `"rocm"`, `"cpu"`, defaulting to `"cpu"`
    - Declare `my.paths.dockerData` (default `/var/lib/docker`), `my.paths.ollamaHome` (default `/opt/ollama`), `my.paths.ollamaModels` (default `/opt/ollama/models`), `my.paths.vllmHome` (default `/opt/vllm`), `my.paths.vllmModels` (default `/opt/vllm/models`), `my.paths.buildScratch` (default `/var/tmp/nix-build`)
    - Use `lib.mkOption` with proper types from `lib.types`
    - _Requirements: 5.1, 5.2, 5.3, 5.10, 11.4_

  - [x] 2.2 Create `modules/profiles/development.nix` profile module
    - Guard entire config block with `lib.mkIf config.my.profiles.development.enable`
    - Enable `programs.ccache`, `programs.nh`, `programs.java`, `programs.adb`
    - Include system-level development packages: gcc13, cmake, meson, ninja, pkg-config, nodejs, openjdk, typescript, node2nix, nil
    - Include AWS tools: awscli2, aws-cdk
    - Include Kubernetes tools: k3s, helm with plugins, helmfile, kustomize, kompose, krew
    - _Requirements: 5.9, 7.6_

  - [x] 2.3 Create `modules/profiles/video-editing.nix` profile module
    - Guard entire config block with `lib.mkIf config.my.profiles.videoEditing.enable`
    - Include kdenlive, ffmpeg-full, mkvtoolnix-cli, darktable, blender
    - _Requirements: 5.8_

  - [x] 2.4 Create `modules/profiles/ai.nix` profile module
    - Guard entire config block with `lib.mkIf config.my.profiles.ai.enable`
    - Accept `pkgsAccel` from `specialArgs` for AI packages
    - Configure dedicated `ollama` user/group with `isSystemUser = true`, `extraGroups = ["video" "render"]`
    - Configure Ollama service: `pkgsAccel.ollama` package, host `0.0.0.0`, port `11434`, acceleration from `config.my.acceleration.backend`, models path from `config.my.paths.ollamaModels`
    - Set Ollama environment variables: `OLLAMA_NUM_PARALLEL`, `OLLAMA_MAX_LOADED_MODELS`, `OLLAMA_FLASH_ATTENTION`, `OLLAMA_KV_CACHE_TYPE`, `OLLAMA_MAX_VRAM`
    - Configure `ollama-create-qwen3-30b-tuned` oneshot service with retry loop and model creation
    - Write `/etc/ollama/qwen3-30b-tuned.Modelfile` via `environment.etc`
    - Configure dedicated `vllm` user/group with `isSystemUser = true`, `extraGroups = ["video" "render"]`
    - Guard vLLM service with `lib.mkIf (config.my.acceleration.backend == "cuda")` — vLLM is CUDA-only
    - Configure vLLM systemd service with CUDA environment variables (CUDA_HOME, LD_LIBRARY_PATH, CUDACXX, etc.)
    - Set up HuggingFace token from sops secrets
    - Create `systemd.tmpfiles.rules` for `/opt/ollama`, `/opt/ollama/models`, `/opt/vllm`, `/opt/vllm/models`
    - Add `system.activationScripts.fixOllamaModelsPerms` for permission fixing
    - Open firewall port 8000 for vLLM
    - Configure Open WebUI service
    - Include AI system packages from `pkgsAccel`: vllm, cudatoolkit, torch, torchvision, torchaudio, diffusers, transformers, accelerate
    - _Requirements: 5.4, 5.5, 9.1, 9.2, 7.2, 7.5_

  - [x] 2.5 Refactor `esnixi/games.nix` to be profile-driven
    - Guard the entire config block with `lib.mkIf config.my.profiles.games.enable`
    - Keep existing Steam configuration: protontricks, gamescopeSession, remotePlay, dedicatedServer, extraPackages, extraCompatPackages (proton-ge-bin)
    - Keep ALVR, xpadneo, gamemode
    - Keep kernel sysctl and PAM limits for Steam
    - _Requirements: 5.6, 7.3_

  - [x] 2.6 Refactor `esnixi/virtualisation.nix` to be profile-driven
    - Guard the entire config block with `lib.mkIf config.my.profiles.virtualization.enable`
    - Configure Docker with `pkgs-old.docker` package, `storageDriver = "btrfs"`, `data-root` from `config.my.paths.dockerData`
    - Keep QEMU/KVM, libvirtd, virt-manager, swtpm configuration
    - Keep KVM kernel modules, nested virtualization, IOMMU params
    - Keep OCI containers (Windows VM) configuration
    - Use canonical paths throughout
    - _Requirements: 5.7, 9.3, 7.4_

- [x] 3. Checkpoint — Verify profile modules
  - Ensure all profile modules are syntactically valid Nix expressions
  - Verify option declarations in `options.nix` cover all profile modules
  - Ask the user if questions arise

- [x] 4. Refactor graphics and flake
  - [x] 4.1 Refactor `esnixi/graphics.nix` to graphics-only
    - Remove all Ollama service configuration (moved to `modules/profiles/ai.nix`)
    - Remove all vLLM service configuration (moved to `modules/profiles/ai.nix`)
    - Remove all AI-related system packages (moved to `modules/profiles/ai.nix`)
    - Remove `users.users.ollama`, `users.groups.ollama`, `users.users.vllm`, `users.groups.vllm` (moved to AI profile)
    - Remove `systemd.tmpfiles.rules` for ollama/vllm (moved to AI profile)
    - Remove `system.activationScripts.fixOllamaModelsPerms` (moved to AI profile)
    - Remove `sops.secrets.huggingface_token` (moved to AI profile)
    - Remove `networking.firewall.allowedTCPPorts` for vLLM (moved to AI profile)
    - Remove `environment.etc."ollama/qwen3-30b-tuned.Modelfile"` (moved to AI profile)
    - Remove `systemd.services."ollama-create-qwen3-30b-tuned"` (moved to AI profile)
    - Keep NVIDIA driver definition (`nvidia-package` with `mkDriver`)
    - Keep `hardware.graphics` configuration (libva, vulkan, OpenGL)
    - Keep `services.xserver.videoDrivers = ["nvidia"]`
    - Keep `hardware.nvidia` configuration (modesetting, power management, open, nvidiaSettings)
    - Keep `services.avahi.publish` settings
    - Keep `libGL`, `nvtopPackages.full` in system packages
    - _Requirements: 7.5, 7.2_

  - [x] 4.2 Refactor `flake.nix` with mkPkgs, mkHost, host matrix, and mapAttrs generation
    - Define `mkPkgs` inline in the `let` block: accepts `{ system, backend, groups }`, sets `cudaSupport`/`rocmSupport` based on `backend`, resolves overlay groups from `overlayGroups`, always sets `allowUnfree = true` and `nvidia.acceptLicense = true`
    - Define `mkHost` inline in the `let` block: accepts `{ hostname, system, backend, groups, extraModules, homeImports }`, calls `mkPkgs` twice (once for `pkgsBase` with `["common" "desktop" "development" "gaming"]` and `backend = "cpu"`, once for `pkgsAccel` with `["common" "ai"]` and the host's backend), creates `pkgsOld` and `pkgsUnstable` without CUDA/ROCm, passes all as `specialArgs`, imports `configuration.nix`, `modules/profiles/options.nix`, profile modules, `extraModules`, configures Home Manager with `homeImports`
    - Define `hosts` attribute set (the host matrix) with entries for `esnixi` and `macland`
    - `esnixi` entry: `system = "x86_64-linux"`, `backend = "cuda"`, `groups` with all profiles enabled, `extraModules` listing esnixi-specific modules and external modules, `homeImports` listing home modules and esnixi hyprland
    - `macland` entry: `system = "x86_64-linux"`, `backend = "rocm"`, `groups` with appropriate profiles, `extraModules` listing macland-specific modules, `homeImports` listing home modules and macland hyprland
    - Generate `nixosConfigurations` via `builtins.mapAttrs (name: cfg: mkHost (cfg // { hostname = name; })) hosts`
    - Remove all inline `let pkgs = import inputs.nixpkgs { ... }` blocks
    - Remove the flat overlay lists from individual host definitions
    - Keep `devShells` output unchanged
    - Set `my.profiles.*` options from the host matrix `groups` (profile flags)
    - Set `my.acceleration.backend` from the host matrix `backend`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 6.1, 6.2, 6.3, 6.4, 6.5, 11.1, 11.2_

  - [x] 4.3 Clean up `configuration.nix` to base-system-only settings
    - Remove any `cudaSupport`, `rocmSupport`, `allowBroken`, `pythonRuntimeDepsCheck` from `nixpkgs.config` (these are now in `mkPkgs`)
    - Remove Steam/gaming configuration (moved to `modules/profiles/games.nix` and `esnixi/games.nix`)
    - Remove Docker configuration (moved to `modules/profiles/virtualization.nix`)
    - Remove AI-related packages from `environment.systemPackages` (moved to `modules/profiles/ai.nix`)
    - Remove development tool packages that are now in `modules/profiles/development.nix`
    - Remove video editing packages that are now in `modules/profiles/video-editing.nix`
    - Keep base system settings: locale, timezone, display manager, Hyprland, audio/PipeWire, printing, fonts, SSH, user definition, keyd, touchegg, base system packages, shared services
    - Keep `nix.settings.experimental-features`
    - Keep `services.wivrn` configuration (VR is host-specific, not profile-driven)
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.6_

- [x] 5. Checkpoint — Phase 1 build verification
  - Run `nix flake check` to verify the refactored flake evaluates without errors
  - Run `nix eval .#nixosConfigurations.esnixi.config.system.build.toplevel` to verify esnixi evaluates
  - Run `nix eval .#nixosConfigurations.macland.config.system.build.toplevel` to verify macland evaluates
  - Ensure all tests pass, ask the user if questions arise
  - _Requirements: 12.1, 12.2, 12.3, 13.1_

- [x] 6. Create storage rebuild script
  - [x] 6.1 Create `scripts/rebuild-storage-layout.sh`
    - Add `#!/usr/bin/env bash` shebang and `set -euo pipefail`
    - Implement `--dry-run` flag parsing
    - Implement timestamped logging function (`log()` with ISO 8601 timestamps)
    - Implement confirmation prompt function that skips in dry-run mode
    - Partition two fast NVMe drives with GPT: swap partition + Btrfs partition each
    - Create Fast Pool Btrfs filesystem with `mkfs.btrfs -d raid0 -m raid1` across both Btrfs partitions
    - Create subvolumes: `@docker`, `@build`, `@ollama`, `@vllm`, `@games`
    - Apply NOCOW attribute (`chattr +C`) to `@docker` and `@build` subvolumes
    - Configure two equal-priority swap partitions (one per fast NVMe) with `mkswap` and `swapon -p 100`
    - Log all operations with timestamps
    - Exit non-zero with descriptive error on any failure
    - _Requirements: 8.1, 8.2, 8.4, 8.5, 8.6, 8.7, 10.1, 10.3, 10.5, 10.7, 11.6_

- [x] 7. Create service migration script
  - [x] 7.1 Create `scripts/migrate-services.sh`
    - Add `#!/usr/bin/env bash` shebang and `set -euo pipefail`
    - Implement `--dry-run` flag parsing
    - Implement timestamped logging function
    - Stop Docker, Ollama, vLLM services via `systemctl stop`
    - Apply NOCOW attribute to target directories before copying
    - Rsync `/home/docker` → `/var/lib/docker` with `-aHAX --info=progress2`
    - Do NOT delete source data (admin removes manually after verification)
    - Log all operations with timestamps
    - Exit non-zero with descriptive error on any failure
    - _Requirements: 9.4, 9.5, 9.6, 9.7, 10.2, 10.4, 10.6, 11.6, 13.2, 13.3_

- [x] 8. Update hardware configuration for two-pool layout
  - [x] 8.1 Update `esnixi/hardware-configuration.nix` with two-pool Btrfs layout
    - Add Fast Pool subvolume mounts: `/var/lib/docker` (`@docker`, compress=zstd, nodatacow), `/var/tmp/nix-build` (`@build`, compress=zstd, nodatacow), `/opt/ollama` (`@ollama`, compress=zstd), `/opt/vllm` (`@vllm`, compress=zstd), `/games` (`@games`, compress=zstd)
    - Replace the single mdadm raid0 swap device with two individual swap partitions at equal priority
    - Set `boot.swraid.enable = false` (no more mdadm dependency)
    - Remove `boot.swraid.mdadmConf` block
    - Keep existing System Pool mounts (`/`, `/home`, `/nix`, `/boot`) unchanged
    - Keep existing `boot.initrd.availableKernelModules` and `boot.kernelModules`
    - Set `nix.settings.build-dir = "/var/tmp/nix-build"` (or add to configuration.nix for esnixi)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 9.8_

- [x] 9. Final checkpoint — Full build and script verification
  - Run `nix flake check` to verify the complete refactored flake
  - Verify `scripts/rebuild-storage-layout.sh` and `scripts/migrate-services.sh` are executable and pass `--dry-run`
  - Run `shellcheck` on both scripts if available
  - Ensure all tests pass, ask the user if questions arise
  - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 13.1, 13.2_

## Notes

- The design explicitly states property-based testing does not apply to this IaC refactoring, so no PBT tasks are included
- `mkPkgs` and `mkHost` are defined inline in `flake.nix` per the user's actual code (not in separate files as originally planned in requirements)
- Profile option names use camelCase: `my.profiles.videoEditing.enable`, `my.paths.dockerData`, etc.
- The host matrix uses `groups` (not `profiles`) as the key name, with `extraModules` and `homeImports`
- vLLM is CUDA-only, guarded by `lib.mkIf (config.my.acceleration.backend == "cuda")`
- Docker uses `pkgsOld.docker` (from `pkgs-old`) and btrfs storage driver
- The AI profile creates dedicated `ollama` and `vllm` users/groups with `isSystemUser = true`
- Phase 1 (tasks 1–5) is committable and buildable independently of Phase 2 (tasks 6–9)
- Checkpoints ensure incremental validation between phases
