# Migration Guide: Modular Home Configuration

## What Changed

Your `home.nix` file has been broken down into logical modules:

### Directory Structure
```
home/
├── default.nix              # Main entry point
├── desktop/
│   ├── hyprland.nix         # Hyprland window manager config
│   ├── quickshell.nix       # Quickshell desktop shell config  
│   └── theming.nix          # Cursors, themes, appearance
├── programs/
│   ├── development.nix      # VSCode, Git, dev tools, Python
│   ├── media.nix            # OBS, media players, image editing
│   ├── productivity.nix     # Browsers, file managers, system tools
│   └── terminal.nix         # Terminal emulators and tools
├── shell/
│   ├── bash.nix             # Bash configuration
│   ├── fish.nix             # Fish shell configuration
│   └── starship.nix         # Starship prompt
└── system/
    ├── files.nix            # Dotfiles and home.file configurations
    ├── packages.nix         # Desktop environment packages
    └── variables.nix        # Environment variables
```

## How to Migrate

### Option 1: Test the New Structure (Recommended)
1. Update your flake.nix to use the new modular config:
   ```nix
   home-manager.users.celes = import ./home-modular.nix;
   ```

2. Test the build:
   ```bash
   sudo nixos-rebuild test --flake .#esnixi  # or #macland
   ```

3. If everything works, make it permanent:
   ```bash
   sudo nixos-rebuild switch --flake .#esnixi
   ```

### Option 2: Keep Both (Gradual Migration)
- Keep your current `home.nix` as backup
- Use `home-modular.nix` for testing
- Switch when you're confident

## Benefits of Modular Structure

1. **Easier Maintenance**: Each module focuses on one area
2. **Better Organization**: Related configurations are grouped together
3. **Selective Imports**: Disable modules you don't need
4. **Collaboration**: Multiple people can work on different modules
5. **Debugging**: Easier to isolate configuration issues

## Customization Examples

### Disable a Module
In `home/default.nix`, comment out imports you don't want:
```nix
imports = [
  # ./programs/media.nix  # Disable if you don't need media apps
  ./programs/development.nix
  # ... other imports
];
```

### Add Platform-Specific Modules
Create platform-specific configurations:
```nix
# home/desktop/macland-specific.nix
# home/desktop/esnixi-specific.nix
```

### Override Module Settings
In any module, you can override settings from other modules:
```nix
# In programs/development.nix
programs.vscode.enable = lib.mkForce false;  # Disable VSCode
```

## Rollback Plan

If something breaks, you can quickly rollback:
1. Change flake.nix back to: `home-manager.users.celes = import ./home.nix;`
2. Run: `sudo nixos-rebuild switch --flake .#esnixi`

## Next Steps

1. Test the modular configuration
2. Customize modules for your needs
3. Consider creating platform-specific modules for esnixi vs macland
4. Remove the old `home.nix` once you're satisfied with the modular version
