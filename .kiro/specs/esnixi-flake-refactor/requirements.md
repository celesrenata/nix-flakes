# Requirements Document

## Introduction

This document specifies the requirements for a major refactoring of the `nix-flakes` NixOS configuration repository. The current flake imports the entire package universe in a mutated state — enabling `cudaSupport = true`, `allowBroken = true`, applying a long overlay list, and injecting a global Python override for `xformers` into a single `pkgs` instance. This causes mass rebuilds, poor binary cache hit rates, and tight coupling between unrelated concerns (gaming, desktop, AI/ML).

The refactoring separates package sets by concern, introduces a profile module system with per-host backend selection, groups overlays into logical sets, restructures the flake with `mkPkgs`/`mkHost` helper functions, redesigns the storage layout for the `esnixi` host, migrates services to canonical paths, and cleans up global configuration pollution.

## Glossary

- **Flake**: The top-level `flake.nix` file that defines inputs, outputs, and NixOS system configurations.
- **Package_Set**: An instantiation of `nixpkgs` via `import inputs.nixpkgs { ... }` with a specific `config` and `overlays` list. Referred to as `pkgs`, `pkgsBase`, `pkgsAccel`, `pkgsOld`, or `pkgsUnstable`.
- **pkgsBase**: The base package set with no global CUDA/ROCm flags and only common overlays applied.
- **pkgsAccel**: The backend-selected accelerator package set consumed only by the AI profile, carrying CUDA or ROCm support and AI-specific overlays.
- **pkgsOld**: The package set imported from the previous stable nixpkgs channel for compatibility.
- **pkgsUnstable**: The package set imported from the nixpkgs-unstable channel for latest versions.
- **Overlay**: A Nix function `(self: super: { ... })` that modifies or extends a package set.
- **Overlay_Group**: A named collection of overlays (e.g., `common`, `desktop`, `development`, `gaming`, `ai`) exported from `overlays/default.nix`.
- **Profile_Module**: A NixOS module under `modules/profiles/` that encapsulates a functional domain (e.g., `games`, `development`, `video-editing`, `virtualization`, `ai`) and is toggled via `my.profiles.<name>.enable`.
- **Options_Module**: The file `modules/profiles/options.nix` that declares all `my.profiles.*`, `my.acceleration.*`, and `my.paths.*` NixOS options.
- **mkPkgs**: A helper function in `lib/mk-pkgs.nix` that creates a package set given a backend selector and overlay group list.
- **mkHost**: A helper function in `mk-host.nix` that creates a full NixOS system configuration given a hostname, backend, profile list, and overlay groups.
- **Host_Matrix**: The top-level declaration in `flake.nix` that maps hostnames to their backend and group selections, currently `esnixi` (CUDA) and `macland` (ROCm).
- **Backend_Selector**: The `my.acceleration.backend` option with values `"cuda"`, `"rocm"`, or `"cpu"`.
- **System_Pool**: A Btrfs filesystem on the system NVMe using raid1 data / raid1 metadata, holding `/`, `/home`, `/nix`, and `/boot`.
- **Fast_Pool**: A Btrfs filesystem on two fast NVMe drives using raid0 data / raid1 metadata, holding `/var/lib/docker`, `/var/tmp/nix-build`, and AI model stores.
- **NOCOW**: The `+C` file attribute (No Copy-on-Write) applied to write-heavy directories to avoid Btrfs fragmentation.
- **Canonical_Path**: A standardized filesystem path for a service (e.g., `/var/lib/docker`, `/opt/ollama/models`, `/opt/vllm/models`, `/var/tmp/nix-build`).
- **Rebuild_Script**: `scripts/rebuild-storage-layout.sh` — a destructive script that repartitions and reformats drives into the two-pool Btrfs layout.
- **Migration_Script**: `scripts/migrate-services.sh` — a conservative script that stops services, rsyncs data to canonical paths, applies NOCOW attributes, and updates configuration.

## Requirements

### Requirement 1: Package Set Separation

**User Story:** As a NixOS maintainer, I want the package universe split into a base set and a backend-specific accelerator set, so that non-AI packages are not polluted with CUDA/ROCm flags and binary cache hit rates improve.

#### Acceptance Criteria

1. THE Flake SHALL define a `pkgsBase` Package_Set that does not set `cudaSupport`, `rocmSupport`, or `allowBroken` to `true` in its config, and applies only the `common` and `desktop` Overlay_Groups.
2. THE Flake SHALL define a `pkgsAccel` Package_Set that sets the appropriate accelerator flag (`cudaSupport` or `rocmSupport`) based on the host's Backend_Selector, and applies the `ai` Overlay_Group in addition to the `common` Overlay_Group.
3. THE Flake SHALL continue to define `pkgsOld` and `pkgsUnstable` Package_Sets, each imported without global CUDA/ROCm flags unless explicitly required by a consuming module.
4. WHEN a host's Backend_Selector is `"cuda"`, THE mkPkgs function SHALL set `cudaSupport = true` in the `pkgsAccel` config.
5. WHEN a host's Backend_Selector is `"rocm"`, THE mkPkgs function SHALL set `rocmSupport = true` in the `pkgsAccel` config.
6. WHEN a host's Backend_Selector is `"cpu"`, THE mkPkgs function SHALL set neither `cudaSupport` nor `rocmSupport` in the `pkgsAccel` config.
7. THE `pkgsBase` Package_Set SHALL NOT contain the global `python3.packageOverrides` for `xformers` that currently exists in the `esnixi` pkgs config.
8. THE `pkgsBase` Package_Set SHALL NOT set `pythonRuntimeDepsCheck = false` globally.

### Requirement 2: mkPkgs Helper Function

**User Story:** As a NixOS maintainer, I want a reusable `mkPkgs` function that creates package sets with specific backends and overlay groups, so that package set creation is consistent and DRY across hosts.

#### Acceptance Criteria

1. THE mkPkgs function SHALL accept parameters for `system`, `backend` (one of `"cuda"`, `"rocm"`, `"cpu"`), and `overlayGroups` (a list of Overlay_Group names).
2. THE mkPkgs function SHALL reside in `lib/mk-pkgs.nix`.
3. THE mkPkgs function SHALL return a fully instantiated Package_Set with the specified config and overlays applied.
4. WHEN the `overlayGroups` parameter includes `"ai"`, THE mkPkgs function SHALL include all AI-specific overlays (vllm, tensorrt, ollama, xformers, comfyui, bitsandbytes) in the returned Package_Set.
5. WHEN the `overlayGroups` parameter does not include `"ai"`, THE mkPkgs function SHALL NOT include AI-specific overlays in the returned Package_Set.
6. THE mkPkgs function SHALL set `allowUnfree = true` and `nvidia.acceptLicense = true` in every Package_Set it creates.

### Requirement 3: mkHost Helper Function

**User Story:** As a NixOS maintainer, I want a reusable `mkHost` function that creates full NixOS system configurations, so that adding new hosts requires only a matrix entry rather than duplicating flake boilerplate.

#### Acceptance Criteria

1. THE mkHost function SHALL accept parameters for `hostname`, `backend`, `profileList` (list of Profile_Module names to enable), and `overlayGroups`.
2. THE mkHost function SHALL reside in `mk-host.nix`.
3. THE mkHost function SHALL call mkPkgs to create both `pkgsBase` and `pkgsAccel` Package_Sets and pass them as `specialArgs` to the NixOS module system.
4. THE mkHost function SHALL import `configuration.nix`, the host-specific directory (`<hostname>/`), and all Profile_Modules listed in `profileList`.
5. THE mkHost function SHALL integrate Home Manager with `useGlobalPkgs = true` and `useUserPackages = true`.
6. WHEN a new hostname is added to the Host_Matrix, THE Flake SHALL produce a valid `nixosConfigurations.<hostname>` output without modifying mkHost or mkPkgs.

### Requirement 4: Overlay Grouping

**User Story:** As a NixOS maintainer, I want overlays organized into named groups, so that each package set loads only the overlays it needs and the overlay list in `flake.nix` is replaced by group references.

#### Acceptance Criteria

1. THE `overlays/default.nix` file SHALL export an attribute set with keys `common`, `desktop`, `development`, `gaming`, and `ai`, each containing a list of overlay functions.
2. THE `common` Overlay_Group SHALL include overlays needed by all hosts (e.g., nixgl, nix-static, helmfile, materialyoucolor, end-4-dots, fuzzel-emoji).
3. THE `desktop` Overlay_Group SHALL include overlays for the desktop environment (e.g., dots-hyprland, keyboard-visualizer, wofi-calc, jetbrains-toolbox, latex).
4. THE `ai` Overlay_Group SHALL include overlays for AI/ML workloads (e.g., vllm, tensorrt, ollama, xformers-bin, comfyui, bitsandbytes, debugpy).
5. THE `gaming` Overlay_Group SHALL include overlays for gaming (e.g., protontweaks).
6. THE `development` Overlay_Group SHALL include overlays for development tools.
7. WHEN an overlay is moved into an Overlay_Group, THE overlay SHALL NOT also appear in the inline overlay list of any Package_Set definition in `flake.nix`.

### Requirement 5: Profile Module System

**User Story:** As a NixOS maintainer, I want selectable profile modules for games, development, video-editing, virtualization, and AI, so that each host enables only the profiles it needs and configuration is cleanly separated by concern.

#### Acceptance Criteria

1. THE Options_Module SHALL declare boolean options `my.profiles.games.enable`, `my.profiles.development.enable`, `my.profiles.video-editing.enable`, `my.profiles.virtualization.enable`, and `my.profiles.ai.enable`, each defaulting to `false`.
2. THE Options_Module SHALL declare a string option `my.acceleration.backend` with allowed values `"cuda"`, `"rocm"`, and `"cpu"`, defaulting to `"cpu"`.
3. THE Options_Module SHALL declare path options `my.paths.ollama-models`, `my.paths.vllm-models`, `my.paths.docker-data`, and `my.paths.build-scratch` with sensible defaults.
4. WHEN `my.profiles.ai.enable` is `true`, THE `modules/profiles/ai.nix` Profile_Module SHALL configure Ollama and vLLM services using `pkgsAccel` and the paths from `my.paths.*`.
5. WHEN `my.profiles.ai.enable` is `false`, THE `modules/profiles/ai.nix` Profile_Module SHALL NOT configure Ollama or vLLM services.
6. WHEN `my.profiles.games.enable` is `true`, THE `modules/profiles/games.nix` Profile_Module SHALL configure Steam, Proton, ALVR, and gaming-related packages.
7. WHEN `my.profiles.virtualization.enable` is `true`, THE `modules/profiles/virtualization.nix` Profile_Module SHALL configure Docker, QEMU/KVM, libvirtd, and virt-manager.
8. WHEN `my.profiles.video-editing.enable` is `true`, THE `modules/profiles/video-editing.nix` Profile_Module SHALL configure kdenlive and related video editing packages.
9. WHEN `my.profiles.development.enable` is `true`, THE `modules/profiles/development.nix` Profile_Module SHALL configure development tools, compilers, and IDEs.
10. THE Options_Module SHALL reside at `modules/profiles/options.nix`.

### Requirement 6: Host Matrix and Flake Restructuring

**User Story:** As a NixOS maintainer, I want a declarative host matrix at the top level of `flake.nix`, so that each host's backend, profiles, and overlay groups are visible in one place.

#### Acceptance Criteria

1. THE Flake SHALL define a `hosts` attribute set where each key is a hostname and each value specifies `backend`, `profiles`, and `overlayGroups`.
2. THE `esnixi` host entry SHALL specify `backend = "cuda"` and enable profiles for `games`, `development`, `video-editing`, `virtualization`, and `ai`.
3. THE `macland` host entry SHALL specify `backend = "rocm"` and enable profiles appropriate for the MacBook T2 hardware.
4. THE Flake SHALL use `builtins.mapAttrs` or equivalent to generate `nixosConfigurations` from the `hosts` attribute set by calling mkHost for each entry.
5. THE Flake SHALL NOT contain inline `let pkgs = import inputs.nixpkgs { ... }` blocks for individual hosts after the refactoring.

### Requirement 7: Configuration Cleanup

**User Story:** As a NixOS maintainer, I want global configuration pollution removed from the base configuration, so that `configuration.nix` contains only true base-system settings and host-specific concerns live in their respective modules.

#### Acceptance Criteria

1. THE `configuration.nix` file SHALL NOT set `cudaSupport`, `rocmSupport`, `allowBroken`, or `pythonRuntimeDepsCheck` in `nixpkgs.config`.
2. THE `configuration.nix` file SHALL NOT contain Ollama, vLLM, or AI service configuration; those SHALL reside in `modules/profiles/ai.nix`.
3. THE `configuration.nix` file SHALL NOT contain Steam, gaming, or Proton configuration; those SHALL reside in `modules/profiles/games.nix` or the host-specific `games.nix`.
4. THE `configuration.nix` file SHALL NOT contain Docker or virtualization configuration beyond what is truly shared; those SHALL reside in `modules/profiles/virtualization.nix`.
5. THE `esnixi/graphics.nix` file SHALL NOT contain Ollama or vLLM service definitions after the refactoring; those SHALL be moved to `modules/profiles/ai.nix`.
6. WHEN the refactoring is complete, THE `configuration.nix` file SHALL contain only base system settings: locale, timezone, display manager, Hyprland, audio, printing, fonts, SSH, user definition, base system packages, and shared services.

### Requirement 8: Storage Layout Redesign

**User Story:** As a system administrator, I want a two-pool Btrfs storage layout separating the system pool from the fast pool, so that write-heavy workloads (Docker, AI models, builds) use striped fast storage while the system pool has redundancy.

#### Acceptance Criteria

1. THE Rebuild_Script SHALL create a System_Pool on the system NVMe with Btrfs raid1 data and raid1 metadata, containing subvolumes for `root`, `home`, `nix`, and `boot`.
2. THE Rebuild_Script SHALL create a Fast_Pool on two fast NVMe drives with Btrfs raid0 data and raid1 metadata, containing subvolumes for `docker`, `build`, and `models`.
3. THE `esnixi/hardware-configuration.nix` file SHALL mount the Fast_Pool subvolumes at `/var/lib/docker`, `/var/tmp/nix-build`, and `/opt` (or individual model paths).
4. THE Rebuild_Script SHALL configure two equal-priority swap partitions (one per fast NVMe) instead of the current mdadm raid0 swap, eliminating the mdadm dependency.
5. THE Rebuild_Script SHALL be located at `scripts/rebuild-storage-layout.sh`.
6. THE Rebuild_Script SHALL include a confirmation prompt before performing destructive operations.
7. THE Rebuild_Script SHALL apply the NOCOW attribute (`+C`) to write-heavy directories: `/var/lib/docker`, `/var/tmp/nix-build`, and AI model store directories.

### Requirement 9: Service Migration

**User Story:** As a system administrator, I want Ollama, vLLM, and Docker migrated to canonical paths with dedicated users and groups, so that services follow FHS conventions and are cleanly separated.

#### Acceptance Criteria

1. WHEN the AI profile is enabled, THE `modules/profiles/ai.nix` Profile_Module SHALL configure the Ollama service with a dedicated `ollama` user and group, storing models at the path specified by `my.paths.ollama-models` (default `/opt/ollama/models`).
2. WHEN the AI profile is enabled, THE `modules/profiles/ai.nix` Profile_Module SHALL configure the vLLM service with a dedicated `vllm` user and group, storing models at the path specified by `my.paths.vllm-models` (default `/opt/vllm/models`).
3. WHEN the virtualization profile is enabled, THE `modules/profiles/virtualization.nix` Profile_Module SHALL configure Docker with `data-root` set to the path specified by `my.paths.docker-data` (default `/var/lib/docker`) and `storageDriver = "btrfs"`.
4. THE Migration_Script SHALL stop running services before moving data.
5. THE Migration_Script SHALL use `rsync` to copy data from old paths (`/home/docker`) to canonical paths (`/var/lib/docker`).
6. THE Migration_Script SHALL apply the NOCOW attribute to target directories before copying data.
7. THE Migration_Script SHALL be located at `scripts/migrate-services.sh`.
8. THE `nix.settings.build-dir` option SHALL be set to `/var/tmp/nix-build` in the system configuration for the `esnixi` host.

### Requirement 10: Helper Scripts

**User Story:** As a system administrator, I want documented helper scripts for the storage rebuild and service migration, so that the multi-phase rollout can be executed safely and repeatably.

#### Acceptance Criteria

1. THE Rebuild_Script SHALL accept a `--dry-run` flag that prints planned operations without executing them.
2. THE Migration_Script SHALL accept a `--dry-run` flag that prints planned operations without executing them.
3. THE Rebuild_Script SHALL log all operations to stdout with timestamps.
4. THE Migration_Script SHALL log all operations to stdout with timestamps.
5. THE Rebuild_Script SHALL exit with a non-zero status code and a descriptive error message if any critical operation fails.
6. THE Migration_Script SHALL exit with a non-zero status code and a descriptive error message if any critical operation fails.
7. IF the Rebuild_Script is run without the `--dry-run` flag, THEN THE Rebuild_Script SHALL prompt the user for confirmation before each destructive operation (partitioning, formatting).

### Requirement 11: File Structure Compliance

**User Story:** As a NixOS maintainer, I want the repository file structure to match the target layout, so that the codebase is organized consistently and new contributors can navigate it.

#### Acceptance Criteria

1. THE repository SHALL contain the file `lib/mk-pkgs.nix`.
2. THE repository SHALL contain the file `mk-host.nix`.
3. THE repository SHALL contain the file `overlays/default.nix` exporting grouped Overlay_Groups.
4. THE repository SHALL contain the file `modules/profiles/options.nix`.
5. THE repository SHALL contain profile module files: `modules/profiles/development.nix`, `modules/profiles/video-editing.nix`, `modules/profiles/ai.nix`, and `modules/profiles/games.nix`.
6. THE repository SHALL contain the files `scripts/rebuild-storage-layout.sh` and `scripts/migrate-services.sh`.
7. THE existing host-specific directories (`esnixi/`, `macland/`) SHALL be preserved with their hardware-configuration and host-specific files.

### Requirement 12: Build Correctness

**User Story:** As a NixOS maintainer, I want the refactored flake to evaluate and build without errors for all hosts, so that the refactoring does not introduce regressions.

#### Acceptance Criteria

1. WHEN `nix flake check` is run against the refactored Flake, THE Flake SHALL pass evaluation without errors.
2. WHEN `nixos-rebuild build --flake .#esnixi` is run, THE system SHALL build to completion without errors.
3. WHEN `nixos-rebuild build --flake .#macland` is run, THE system SHALL build to completion without errors.
4. WHEN the `esnixi` host is built, THE system closure SHALL include CUDA-accelerated Ollama and vLLM packages from `pkgsAccel`.
5. WHEN the `macland` host is built, THE system closure SHALL NOT include CUDA-specific packages.
6. WHEN the `esnixi` host is built with all profiles enabled, THE system closure SHALL include Steam, Docker, kdenlive, development tools, Ollama, and vLLM.

### Requirement 13: Rollout Plan Support

**User Story:** As a system administrator, I want the refactoring to support a phased rollout, so that I can apply changes incrementally and roll back if issues arise.

#### Acceptance Criteria

1. THE flake and profile refactoring (Requirements 1-7, 11) SHALL be committable and buildable independently of the storage layout changes (Requirement 8).
2. THE service migration (Requirement 9) SHALL be executable independently of the storage layout rebuild (Requirement 8).
3. THE Migration_Script SHALL preserve original data at the source path until the administrator explicitly removes it.
4. IF a build fails after applying the flake refactoring, THEN THE administrator SHALL be able to revert to the previous commit and rebuild successfully using the old flake structure.
