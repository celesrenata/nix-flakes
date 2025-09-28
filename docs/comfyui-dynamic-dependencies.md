# ComfyUI Dynamic Dependencies Setup

This document explains how we configured ComfyUI to support dynamic dependency installation for custom nodes.

## Problem

ComfyUI custom nodes require various Python packages (opencv, piexif, numba, gguf, etc.) that aren't part of the core ComfyUI installation. These dependencies need to be installed dynamically as custom nodes are added.

## Solution Overview

We implemented a hybrid approach:
1. **Nix-shell environment** with `uv` for package management tools
2. **Direct venv installation** for common dependencies
3. **ComfyUI Manager** for dynamic installation of remaining packages

## Implementation Steps

### 1. Nix-shell Wrapper

Modified the ComfyUI wrapper to run in a nix-shell with required tools:

```nix
comfyui-wrapper = pkgs.writeShellScript "comfyui-wrapper" ''
  exec ${pkgs.nix}/bin/nix-shell -p uv git python3 --run "
    export PATH=\$PATH
    export VIRTUAL_ENV=${config.home.homeDirectory}/.config/comfy-ui/venv
    ${comfyui}/bin/comfy-ui $*
  "
'';
```

### 2. Service Environment

Set up proper environment variables for the systemd service:

```nix
Environment = [
  "VIRTUAL_ENV=${config.home.homeDirectory}/.config/comfy-ui/venv"
  "PATH=${config.home.homeDirectory}/.config/comfy-ui/venv/bin:${pkgs.uv}/bin:/run/current-system/sw/bin"
  # ... other environment variables
];
```

### 3. ComfyUI Overlay

Added `uv` to the ComfyUI package for package management:

```nix
propagatedBuildInputs = with prev.python3Packages; [
  # ... core dependencies
] ++ [ prev.uv ];
```

### 4. Manual Dependency Installation

For immediate functionality, installed common dependencies directly:

```bash
cd /home/celes/.config/comfy-ui
./venv/bin/pip install opencv-python piexif numba gguf nunchaku
```

## Results

### Successfully Loading Custom Nodes
- comfyui-image-saver (piexif dependency)
- ComfyUI-GGUF (gguf dependency)
- ComfyUI-nunchaku (nunchaku dependency)
- was-node-suite-comfyui (numba dependency)
- ComfyUI-Manager (core functionality)

### Still Failing Nodes
- comfyui_tensorrt (requires proprietary tensorrt package)
- Some opencv-dependent nodes (may need additional opencv modules)

## Key Learnings

1. **Venv Isolation**: Nix overlay dependencies don't automatically propagate to Python venvs
2. **Subprocess Environment**: ComfyUI Manager's subprocess calls need explicit environment setup
3. **Hybrid Approach**: Combining Nix tools with direct pip installation works best
4. **Prestartup Issues**: ComfyUI Manager's prestartup script may fail but core functionality still works

## Future Improvements

1. Fix the `uv pip freeze` prestartup script issue for automatic dependency checking
2. Add more common dependencies to reduce manual installation needs
3. Create a script to automatically install missing dependencies based on error logs

## Usage

After this setup:
1. ComfyUI runs with access to `uv` for package management
2. Common custom node dependencies are pre-installed
3. ComfyUI Manager can install additional packages through its web interface
4. New custom nodes should work with minimal manual intervention

## Troubleshooting

If custom nodes fail to load:
1. Check the ComfyUI logs for `ModuleNotFoundError` messages
2. Install missing packages directly: `./venv/bin/pip install <package-name>`
3. Restart ComfyUI service: `systemctl --user restart comfyui`
4. Use ComfyUI Manager's web interface to install custom node dependencies
