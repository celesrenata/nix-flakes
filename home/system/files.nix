# Home directory file management and dotfiles
{ inputs, lib, pkgs, ... }:

let
  celes-dots = pkgs.fetchFromGitHub {
    owner = "celesrenata";
    repo = "dotfiles";
    rev = "84ffef9c6f9c0fb204cf7e3561d6dd05434b115c";
    sha256 = "sha256-RwK8A7kBCrNlU+Y7Nfc0P0jK8WO6d3fo49T65CZo+F8=";
  };
  
  wofi-calc = pkgs.fetchFromGitHub {
    owner = "Zeioth";
    repo = "wofi-calc";
    rev = "edd316f3f40a6fcb2afadf5b6d9b14cc75a901e0";
    sha256 = "sha256-y8GoTHm0zPkeXhYS/enNAIrU+RhrUMnQ41MdHWWTPas=";
  };
  
  winapps = pkgs.fetchFromGitHub {
    owner = "celesrenata";
    repo = "winapps";
    rev = "0319c70fa0dec2da241e9a4b4e35a164f99d6307";
    sha256 = "sha256-+ZAtEDrHuLJBzF+R6guD7jYltoQcs88qEMvvpjiAXqI=";
  };

  quickshellSource = pkgs.runCommand "dots-quickshell-overview" { } ''
    cp -r ${if pkgs ? dots-hyprland-source-filtered
      then pkgs.dots-hyprland-source-filtered
      else inputs.dots-hyprland-source}/.config/quickshell $out
    chmod -R u+w $out
    for qs_root in "$out" "$out/ii"; do
      substituteInPlace "$qs_root/services/HyprlandData.qml" \
        --replace-fail $'    function updateAll() {\n        updateWindowList();\n        updateMonitors();\n        updateLayers();\n        updateWorkspaces();\n    }' $'    function updateAll() {\n        updateWindowList();\n        updateMonitors();\n        updateLayers();\n        updateWorkspaces();\n    }\n\n    // Hyprland 0.5 uses activeWorkspace.name in monitors -j; older releases used id.\n    // Accept the Quickshell monitor object so both its ID and connector name can match.\n    function workspaceIdForMonitor(hyprMonitor) {\n        const monitorId = hyprMonitor && hyprMonitor.id !== undefined ? hyprMonitor.id : hyprMonitor\n        const monitorName = hyprMonitor && hyprMonitor.name ? hyprMonitor.name : ""\n        const monitor = root.monitors.find(m => m.id === monitorId || m.name === monitorName)\n            || root.monitors.find(m => root.activeWorkspace && m.id === root.activeWorkspace.monitorID)\n        const activeWorkspace = monitor && monitor.activeWorkspace ? monitor.activeWorkspace : root.activeWorkspace\n        const workspaceValue = activeWorkspace && activeWorkspace.id !== undefined ? activeWorkspace.id : activeWorkspace ? activeWorkspace.name : 0\n        const workspaceId = Number(workspaceValue)\n        console.warn("[workspace resolver]", monitorId, monitorName, workspaceValue, workspaceId)\n        return workspaceId > 0 ? workspaceId : 1\n    }'
      substituteInPlace "$qs_root/services/HyprlandData.qml" \
        --replace-fail '        console.warn("[workspace resolver]", monitorId, monitorName, workspaceValue, workspaceId)' ""
    done
    substituteInPlace "$out/ii/qs/services/HyprlandData.qml" \
      --replace-fail $'    function updateAll() {\n        updateWindowList();\n        updateMonitors();\n        updateLayers();\n        updateWorkspaces();\n    }' $'    function updateAll() {\n        updateWindowList();\n        updateMonitors();\n        updateLayers();\n        updateWorkspaces();\n    }\n\n    // Hyprland 0.5 uses activeWorkspace.name in monitors -j; older releases used id.\n    // Match the Quickshell monitor by numeric ID or connector name.\n    function workspaceIdForMonitor(hyprMonitor) {\n        const monitorId = hyprMonitor && hyprMonitor.id !== undefined ? hyprMonitor.id : hyprMonitor\n        const monitorName = hyprMonitor && hyprMonitor.name ? hyprMonitor.name : ""\n        const monitor = root.monitors.find(m => m.id === monitorId || m.name === monitorName)\n            || root.monitors.find(m => root.activeWorkspace && m.id === root.activeWorkspace.monitorID)\n        const activeWorkspace = monitor && monitor.activeWorkspace ? monitor.activeWorkspace : root.activeWorkspace\n        const workspaceValue = activeWorkspace && activeWorkspace.id !== undefined ? activeWorkspace.id : activeWorkspace ? activeWorkspace.name : 0\n        const workspaceId = Number(workspaceValue)\n        return workspaceId > 0 ? workspaceId : 1\n    }'
    substituteInPlace $out/modules/overview/OverviewWidget.qml \
      --replace-fail 'readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - 1) / workspacesShown)' 'readonly property int workspaceGroup: Math.floor((HyprlandData.workspaceIdForMonitor(monitor) - 1) / workspacesShown)' \
      --replace-fail '((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)' 'Math.max(1, (monitor.height - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[0] : 0)) - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[2] : 0))) * root.scale / Math.max(monitor.scale || 1, 0.01))' \
      --replace-fail '((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)' 'Math.max(1, (monitor.width - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[0] : 0)) - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[2] : 0))) * root.scale / Math.max(monitor.scale || 1, 0.01))' \
      --replace-fail '((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)' 'Math.max(1, (monitor.width - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[1] : 0)) - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[3] : 0))) * root.scale / Math.max(monitor.scale || 1, 0.01))' \
      --replace-fail '((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)' 'Math.max(1, (monitor.height - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[1] : 0)) - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[3] : 0))) * root.scale / Math.max(monitor.scale || 1, 0.01))' \
      --replace-fail 'monitorData: HyprlandData.monitors[monitorId]' 'monitorData: HyprlandData.monitors[monitorId] ? HyprlandData.monitors[monitorId] : ({ x: 0, y: 0, reserved: [0, 0, 0, 0], scale: 1 })' \
      --replace-fail 'monitorData?.reserved[0]) * root.scale' 'Math.max(0, monitorData?.reserved?.[0] ?? 0)) * root.scale' \
      --replace-fail 'monitorData?.reserved[1]) * root.scale' 'Math.max(0, monitorData?.reserved?.[1] ?? 0)) * root.scale' \
      --replace-fail 'property int activeWorkspaceInGroup: monitor.activeWorkspace?.id -' 'property int activeWorkspaceInGroup: HyprlandData.workspaceIdForMonitor(monitor) -'
    substituteInPlace $out/modules/overview/OverviewWindow.qml \
      --replace-fail 'windowData?.at[0] - (monitorData?.x ?? 0) - monitorData?.reserved[0]' '(windowData && windowData.at ? windowData.at[0] : 0) - (monitorData?.x ?? 0) - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[0] : 0))' \
      --replace-fail 'windowData?.at[1] - (monitorData?.y ?? 0) - monitorData?.reserved[1]' '(windowData && windowData.at ? windowData.at[1] : 0) - (monitorData?.y ?? 0) - Math.max(0, (monitorData && monitorData.reserved ? monitorData.reserved[1] : 0))' \
      --replace-fail 'width: windowData?.size[0] * root.scale' 'width: Math.max(1, (windowData?.size?.[0] ?? 1) * root.scale)' \
      --replace-fail 'height: windowData?.size[1] * root.scale' 'height: Math.max(1, (windowData?.size?.[1] ?? 1) * root.scale)'
    substituteInPlace $out/modules/overview/OverviewWidget.qml \
      --replace-fail 'const address = `0x''${toplevel.HyprlandToplevel.address}`' $'const rawAddress = String(toplevel.HyprlandToplevel.address)\n                            const address = rawAddress.startsWith("0x") ? rawAddress : `0x''${rawAddress}`' \
      --replace-fail 'property var address: `0x''${modelData.HyprlandToplevel.address}`' 'property var address: modelData.address' \
      --replace-fail $'model: ScriptModel {\n                    values: {\n                        // console.log(JSON.stringify(ToplevelManager.toplevels.values.map(t => t), null, 2))\n                        return ToplevelManager.toplevels.values.filter((toplevel) => {\n                            const rawAddress = String(toplevel.HyprlandToplevel.address)\n                            const address = rawAddress.startsWith("0x") ? rawAddress : `0x''${rawAddress}`\n                            var win = windowByAddress[address]\n                            const inWorkspaceGroup = (root.workspaceGroup * root.workspacesShown < win?.workspace?.id && win?.workspace?.id <= (root.workspaceGroup + 1) * root.workspacesShown)\n                            const inMonitor = root.monitor.id === win.monitor\n                            return inWorkspaceGroup && inMonitor;\n                        })\n                    }\n                }' $'model: HyprlandData.windowList.filter(win => {\n                    const inWorkspaceGroup = root.workspaceGroup * root.workspacesShown < win.workspace.id && win.workspace.id <= (root.workspaceGroup + 1) * root.workspacesShown\n                    return inWorkspaceGroup && root.monitor.id === win.monitor\n                })' \
      --replace-fail 'windowData: windowByAddress[address]' 'windowData: modelData' \
      --replace-fail 'windowData: modelData' $'windowData: modelData\n                    readonly property int workspaceId: Number(windowData?.workspace?.id ?? windowData?.workspace?.name ?? 1)' \
      --replace-fail 'toplevel: modelData' $'toplevel: ToplevelManager.toplevels.values.find(toplevel => {\n                        const rawAddress = String(toplevel.HyprlandToplevel.address)\n                        return (rawAddress.startsWith("0x") ? rawAddress : `0x''${rawAddress}`) === modelData.address\n                    })'
    substituteInPlace $out/modules/overview/OverviewWidget.qml \
      --replace-fail 'const inWorkspaceGroup = root.workspaceGroup * root.workspacesShown < win.workspace.id && win.workspace.id <= (root.workspaceGroup + 1) * root.workspacesShown' $'const workspaceId = Number(win.workspace.id !== undefined ? win.workspace.id : win.workspace.name)\n                    const inWorkspaceGroup = root.workspaceGroup * root.workspacesShown < workspaceId && workspaceId <= (root.workspaceGroup + 1) * root.workspacesShown' \
      --replace 'windowData?.workspace.id' 'workspaceId' \
      --replace-fail 'property int draggingTargetWorkspace: -1' $'property int draggingTargetWorkspace: -1\n\n    function workspaceAtPosition(x, y) {\n        const column = Math.floor(x / (workspaceImplicitWidth + workspaceSpacing))\n        const row = Math.floor(y / (workspaceImplicitHeight + workspaceSpacing))\n        if (column < 0 || column >= Config.options.overview.columns || row < 0 || row >= Config.options.overview.rows) return -1\n        return workspaceGroup * workspacesShown + row * Config.options.overview.columns + column + 1\n    }\n\n    function moveWindowToWorkspace(address, workspace) {\n        const workspaceId = Number(workspace)\n        if (!Number.isInteger(workspaceId) || workspaceId < 1 || !address) return\n        const lua = `return hl.dispatch(hl.dsp.window.move({ workspace = "''${workspaceId}", silent = true, window = "address:''${address}" }))`\n        Quickshell.execDetached(["hyprctl", "eval", lua])\n    }' \
      --replace-fail $'                            DropArea {\n                                anchors.fill: parent\n                                onEntered: {' $'                            DropArea {\n                                anchors.fill: parent\n                                onDropped: drop => {\n                                    const source = drop.source\n                                    if (source && source.windowData && source.workspaceId !== workspaceValue)\n                                        Hyprland.dispatch(`movetoworkspacesilent ''${workspaceValue}, address:''${source.windowData.address}`)\n                                }\n                                onEntered: {'
    substituteInPlace $out/modules/overview/OverviewWidget.qml \
      --replace 'Hyprland.dispatch(`movetoworkspacesilent ''${workspaceValue}, address:''${source.windowData.address}`)' 'root.moveWindowToWorkspace(source.windowData.address, workspaceValue)' \
      --replace 'Hyprland.dispatch(`movetoworkspacesilent ''${targetWorkspace}, address:''${window.windowData?.address}`)' 'root.moveWindowToWorkspace(window.windowData?.address, targetWorkspace)'
    substituteInPlace $out/modules/overview/OverviewWidget.qml \
      --replace-fail $'                                    const source = drop.source\n                                    if (source && source.windowData' $'                                    const source = drop.source\n                                    drop.accepted = true\n                                    if (source && source.windowData'
    substituteInPlace $out/modules/overview/OverviewWidget.qml \
      --replace-fail $'                            window.pressed = false\n                            window.Drag.active = false' $'                            window.pressed = false\n                            const dropAction = window.Drag.drop()\n                            window.Drag.active = false' \
      --replace-fail 'if (targetWorkspace !== -1 && targetWorkspace !== workspaceId) {' 'if (dropAction !== Qt.IgnoreAction) {' \
      --replace-fail 'root.moveWindowToWorkspace(window.windowData?.address, targetWorkspace)' ""
    substituteInPlace $out/modules/overview/OverviewWidget.qml \
      --replace-fail 'silent = true' 'follow = false'
    substituteInPlace $out/modules/overview/OverviewWidget.qml \
      --replace-fail 'Quickshell.execDetached(["hyprctl", "eval", lua])' 'Quickshell.execDetached(["bash", "-c", "env -u LD_LIBRARY_PATH hyprctl eval \"$1\"", "bash", lua])'
    if [ -d "$out/ii/modules/overview" ]; then
      cp $out/modules/overview/OverviewWidget.qml $out/ii/modules/overview/OverviewWidget.qml
      cp $out/modules/overview/OverviewWindow.qml $out/ii/modules/overview/OverviewWindow.qml
    fi
    for qs_modules in "$out/modules" "$out/ii/modules"; do
      substituteInPlace "$qs_modules/common/models/WorkspaceModel.qml" \
        --replace-fail 'readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1' 'readonly property int activeWorkspace: HyprlandData.workspaceIdForMonitor(monitor)'
      substituteInPlace "$qs_modules/bar/WorkspacesHefty.qml" \
        --replace-fail 'property int workspaceIndexInGroup: (monitor?.activeWorkspace?.id - 1) % wsModel.shownCount' 'property int workspaceIndexInGroup: (wsModel.activeWorkspace - 1) % wsModel.shownCount' \
        --replace-fail 'id: interactionIndicator' $'id: interactionIndicator\n            visible: false' \
        --replace-fail 'property color contentColor: (wsModel.occupied[wsNum.index] && wsId !== wsModel.fakeWorkspace) ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1Inactive' 'property color contentColor: wsId === wsModel.activeWorkspace ? Appearance.colors.colOnPrimary : (wsModel.occupied[wsNum.index] && wsId !== wsModel.fakeWorkspace) ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1Inactive' \
        --replace-fail $'Colorizer {\n            z: 5' $'Colorizer {\n            visible: false\n            z: 5'
      substituteInPlace "$qs_modules/bar/WorkspacesDefault.qml" \
        --replace-fail 'readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - 1) / Config.options.bar.workspaces.shown)' 'readonly property int workspaceGroup: Math.floor((HyprlandData.workspaceIdForMonitor(monitor) - 1) / Config.options.bar.workspaces.shown)' \
        --replace-fail 'property int workspaceIndexInGroup: (monitor.activeWorkspace?.id - 1) % Config.options.bar.workspaces.shown' 'property int workspaceIndexInGroup: (HyprlandData.workspaceIdForMonitor(monitor) - 1) % Config.options.bar.workspaces.shown' \
        --replace 'monitor.activeWorkspace?.id === index' 'HyprlandData.workspaceIdForMonitor(monitor) === index' \
        --replace 'monitor.activeWorkspace?.id === index+2' 'HyprlandData.workspaceIdForMonitor(monitor) === index+2' \
        --replace 'monitor.activeWorkspace?.id === index+1' 'HyprlandData.workspaceIdForMonitor(monitor) === index+1' \
        --replace 'monitor.activeWorkspace?.id == button.workspaceValue' 'HyprlandData.workspaceIdForMonitor(monitor) == button.workspaceValue'
    done
  '';
in
{
  # Dotfiles and configuration files
  home.file."Pictures/Wallpapers" = {
    source = celes-dots + "/Backgrounds";
    recursive = true;
  }; 
  
  # Winapps configuration
  home.file."winapps/pkg" = {
    source = winapps;
    recursive = true;
    executable = true;
  };
  
  home.file."winapps/runmefirst.sh" = {
    source = winapps + "/runmefirst.sh";
  };
  
  # ── Systemd oneshot: initial wallpaper/colorgen (needs Hyprland) ─────
  systemd.user.services.dots-initial-colorgen = {
    Unit = {
      Description = "Initial wallpaper and color scheme generation";
      After = [ "graphical-session.target" ];
      ConditionPathExists = "!%h/.local/share/initialSetup";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = [
        "PATH=/etc/profiles/per-user/celes/bin:/run/current-system/sw/bin"
        "LD_LIBRARY_PATH="
      ];
      ExecStart = toString (pkgs.writeShellScript "dots-initial-colorgen" ''
        sleep 3  # let Hyprland settle
        imgpath="$(readlink -f "$HOME/Pictures/Wallpapers/love-is-love.jpg")"
        if [ -f "$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh" ]; then
          "$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh" "$imgpath"
        fi
        touch "$HOME/.local/share/initialSetup"
      '');
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Staging directory for mutable configs (used by dotsSetup activation)
  home.file.".configstaging/quickshell" = {
    source = quickshellSource;
    recursive = true;
  };
  
  home.file.".configstaging/matugen" = {
    source = inputs.dots-hyprland-source + "/.config/matugen";
    recursive = true;
  };
  
  home.file.".configstaging/hypr/hyprland" = {
    source = inputs.dots-hyprland-source + "/.config/hypr/hyprland";
    recursive = true;
  };

  # Local bin scripts
  # ── Home activation: replaces initialSetup.sh ──────────────────────────
  home.activation.dotsSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Icons: ensure real directory (Steam writes here)
    if [ -L "$HOME/.local/share/icons" ]; then
      rm "$HOME/.local/share/icons"
    fi
    mkdir -p "$HOME/.local/share/icons"
    cp -n ${inputs.dots-hyprland-source}/.local/share/icons/* "$HOME/.local/share/icons/" 2>/dev/null || true

    # Create mutable config directories
    mkdir -p "$HOME/.config/foot"
    mkdir -p "$HOME/.config/fuzzel"
    mkdir -p "$HOME/.config/gtk-4.0"
    mkdir -p "$HOME/.config/hypr/custom/scripts"
    mkdir -p "$HOME/.local/state/quickshell/user/generated"/{foot,terminal,fuzzel,wallpaper}
    mkdir -p "$HOME/Videos"

    # Remove stale matugen symlink (managed via staging)
    if [ -L "$HOME/.config/matugen" ]; then
      rm "$HOME/.config/matugen"
    fi

    # Keep Quickshell code in lockstep with the pinned source. Runtime/user state
    # lives under ~/.local/state/quickshell, while the separate touch config is
    # managed independently and must survive this sync.
    chmod -R u+w "$HOME/.config/" "$HOME/.local/state/quickshell/" 2>/dev/null || true
    mkdir -p "$HOME/.config/quickshell"
    ${pkgs.rsync}/bin/rsync -azL --delete --no-perms \
      --exclude='/touch/' \
      "$HOME/.configstaging/quickshell/" "$HOME/.config/quickshell/"

    # The remaining staged programs are intentionally mutable.
    ${pkgs.rsync}/bin/rsync -azL --no-perms \
      --exclude='/quickshell/' \
      "$HOME/.configstaging/" "$HOME/.config/"
    chmod -R u+w "$HOME/.local/state/quickshell/user/generated/" \
      "$HOME/.config/fuzzel/" "$HOME/.config/foot/" "$HOME/.config/gtk-4.0/" \
      "$HOME/.config/hypr/hyprland/" "$HOME/.config/matugen/" 2>/dev/null || true

    # Default custom.conf if missing
    if [ ! -f "$HOME/.config/hypr/custom.conf" ]; then
      echo "monitor=,preferred,auto,1" > "$HOME/.config/hypr/custom.conf"
    fi

    # Sync system touchegg config to user config
    mkdir -p "$HOME/.config/touchegg"
    cp /etc/touchegg/touchegg.conf "$HOME/.config/touchegg/touchegg.conf" 2>/dev/null || true
  '';

  # Config.qml is replaced by the declarative module after staging. Remove the
  # staging copy's one-generation backup only after Home Manager has linked it.
  home.activation.cleanupQuickshellConfigBackup =
    lib.hm.dag.entryAfter ["linkGeneration"] ''
      rm -f "$HOME/.config/quickshell/ii/modules/common/Config.qml.backup"
    '';

  home.activation.fixWorkspaceAction = lib.hm.dag.entryAfter ["dotsSetup"] ''
    install -Dm755 ${./workspace-action.sh} "$HOME/.config/hypr/hyprland/scripts/workspace_action.sh"
  '';
  
  home.file.".local/bin/apply-idle-config.sh" = {
    executable = true;
    source = ./scripts/apply-idle-config.sh;
  };

  home.file.".local/bin/sync-rgb.sh" = {
    executable = true;
    source = ./scripts/sync-rgb.sh;
  };

  home.file.".local/bin/winapps" = {
    executable = true;
    source = "${winapps}/bin/winapps";
  };

  home.file.".local/bin/winapps-autoinstall.sh" = {
    executable = true;
    source = ./scripts/winapps-autoinstall.sh;
  };

  home.file.".local/bin/sunshine" = {
    source = celes-dots + "/.local/bin/sunshineFixed";
  };
  
  home.file.".local/bin/agsAction.sh" = {
    source = celes-dots + "/.local/bin/agsAction.sh";
  };
  
  home.file.".local/bin/regexEscape.sh" = {
    source = celes-dots + "/.local/bin/regexEscape.sh";
  };
  
  home.file.".local/bin/wofi-calc" = {
    source = wofi-calc + "/wofi-calc.sh";
  };
  
  # Fish auto-completion scripts (manual copy to avoid fish_variables conflicts)
  home.file.".config/fish/auto-Hypr.fish" = {
    source = "${inputs.dots-hyprland-source}/.config/fish/auto-Hypr.fish";
  };

  # Commented out Toshy-related files (replaced by keyd)
  # These are kept as comments for reference in case you want to re-enable Toshy
  
  # home.file.".configstaging/toshy/toshy_config.py" = {
  #   source = "${pkgs.toshy}/toshy_config.py";
  # };
  # home.file.".configstaging/toshy/toshy_user_preferences.sqlite" = {
  #   source = "${pkgs.toshy}/toshy_user_preferences.sqlite";
  # };
  
  # Multiple Toshy bin scripts would go here...
  # (commented out for brevity - they're all in the original file)
}
