-- esnixi host-specific Hyprland overrides
-- This file runs AFTER the base dots-hyprland config and contains
-- esnixi-specific configuration: DP-3 Hyte touch display isolation,
-- custom keybinds, environment overrides, and autostart commands.

-------------------------------------------------------------------------------
-- MONITOR: DP-3 Hyte Touch Display
-------------------------------------------------------------------------------

-- DP-3 workspace isolation
hl.workspace_rule({ workspace = "name:touch", monitor = "DP-3", default = true, gaps_in = 0, gaps_out = 0, border_size = 0 })

-------------------------------------------------------------------------------
-- DEVICE: ILITEK Touch → DP-3
-------------------------------------------------------------------------------

hl.device({ name = "ilitek-------ilitek-touch", output = "DP-3", enabled = true, transform = 3 })

-------------------------------------------------------------------------------
-- CURSOR: DP-3 touch optimizations
-------------------------------------------------------------------------------

hl.config({
    cursor = {
        no_warps = true,
        hide_on_touch = true,
        inactive_timeout = 0,
    },
})

-------------------------------------------------------------------------------
-- TOUCH INPUT
-------------------------------------------------------------------------------

hl.config({
    input = {
        touchdevice = {
            output = "DP-3",
            transform = 3,
        },
    },
})

-------------------------------------------------------------------------------
-- ENVIRONMENT VARIABLES
-------------------------------------------------------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("OLLAMA_HOST", "http://10.1.1.12:2701")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
hl.env("GLFW_IM_MODULE", "ibus")
hl.env("INPUT_METHOD", "fcitx")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-")
hl.env("TERMINAL", "foot")

-------------------------------------------------------------------------------
-- INPUT CONFIGURATION
-------------------------------------------------------------------------------

hl.config({
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",

        follow_mouse = 1,
        sensitivity = 0, -- -1.0 to 1.0, 0 means no modification

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            middle_button_emulation = true,
        },
    },
})

-------------------------------------------------------------------------------
-- GENERAL APPEARANCE
-------------------------------------------------------------------------------

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 7,
        border_size = 2,
        ["col.active_border"] = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
        ["col.inactive_border"] = "rgba(595959aa)",
        layout = "dwindle",
        allow_tearing = false,
    },
})

-------------------------------------------------------------------------------
-- DECORATION
-------------------------------------------------------------------------------

hl.config({
    decoration = {
        rounding = 16,

        blur = {
            enabled = true,
            size = 3,
            passes = 1,
        },

        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
    },
})

-------------------------------------------------------------------------------
-- ANIMATIONS
-------------------------------------------------------------------------------

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

-------------------------------------------------------------------------------
-- LAYOUT
-------------------------------------------------------------------------------

hl.config({
    dwindle = {
        preserve_split = true,
    },
})

hl.config({
    master = {
        new_status = "master",
    },
})

-------------------------------------------------------------------------------
-- GESTURES
-------------------------------------------------------------------------------

-- 3-finger horizontal workspace gesture already defined in general.lua
-- Custom gesture actions not supported in 0.55+ gesture API (use keybinds instead)
-- hl.gesture({ fingers = 4, direction = "pinchin", action = "fullscreen 1" })
-- hl.gesture({ fingers = 4, direction = "pinchout", action = "fullscreen 1" })
-- hl.gesture({ fingers = 4, direction = "left", action = "exec ~/.local/bin/gesture-toggle.sh left" })
-- hl.gesture({ fingers = 4, direction = "right", action = "exec ~/.local/bin/gesture-toggle.sh right" })
-- hl.gesture({ fingers = 4, direction = "up", action = "exec ~/.local/bin/gesture-toggle.sh up" })
-- hl.gesture({ fingers = 4, direction = "down", action = "exec ~/.local/bin/gesture-toggle.sh down" })

-------------------------------------------------------------------------------
-- MISC
-------------------------------------------------------------------------------

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = false,
        key_press_enables_dpms = false,
        force_default_wallpaper = -1,
    },
})

-------------------------------------------------------------------------------
-- WINDOW RULES
-------------------------------------------------------------------------------

-- Hyte touch interface locked to DP-3 fullscreen
hl.window_rule({ name = "hyte-touch", match = { title = "^(hyte-touch-interface)$" }, monitor = "DP-3", fullscreen = true })

-- ProjectM visualizer - on touch workspace behind QuickShell
hl.window_rule({ name = "projectm", match = { class = "^(projectMSDL)$" }, workspace = "name:touch", monitor = "DP-3", fullscreen = true })

-- OneTrainer - force decorations on Xwayland Tk windows
hl.window_rule({ name = "onetrainer-tk", match = { class = "^(Tk)$" }, tile = true, decorate = true })

-- Xwayland windows get decorations
hl.window_rule({ name = "xwayland-decorate", match = { xwayland = true }, decorate = true })

-- Suppress maximize for all windows
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-------------------------------------------------------------------------------
-- VOICE DICTATION (keyd outputs Ctrl+H for Logi button)
-------------------------------------------------------------------------------

hl.bind("Ctrl + H", hl.dsp.global("quickshell:dictationTap"), { description = "Voice dictation tap" })

-------------------------------------------------------------------------------
-- KEYBINDS: System Controls
-------------------------------------------------------------------------------

-- Volume
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-"), { locked = true, repeating = true })

-------------------------------------------------------------------------------
-- KEYBINDS: Applications
-------------------------------------------------------------------------------

-- Music
hl.bind("Ctrl + Super + M", hl.dsp.exec_cmd("tidal-hifi"), { description = "Tidal HiFi" })
hl.bind("Ctrl + Shift + Super + M", hl.dsp.exec_cmd("env -u NIXOS_OZONE_WL cider --use-gl=desktop"), { description = "Cider" })
hl.bind("Ctrl + Alt + Super + M", hl.dsp.exec_cmd("spotify"), { description = "Spotify" })

-- Discord
hl.bind("Ctrl + Super + I", hl.dsp.exec_cmd("discord"), { description = "Discord" })

-- Terminal (Foot)
hl.bind("Ctrl + Super + G", hl.dsp.exec_cmd("foot"), { description = "Foot terminal" })
hl.bind("Ctrl + Shift + Super + T", hl.dsp.exec_cmd("foot sleep 0.01 && nmtui"), { description = "Network manager TUI" })

-- File managers
hl.bind("Ctrl + Super + J", hl.dsp.exec_cmd("thunar"), { description = "Thunar" })
hl.bind("Ctrl + Shift + Super + J", hl.dsp.exec_cmd("nautilus"), { description = "Nautilus" })

-- Browsers
hl.bind("Ctrl + Super + B", hl.dsp.exec_cmd("firefox"), { description = "Firefox" })
hl.bind("Ctrl + Shift + Super + B", hl.dsp.exec_cmd("chromium"), { description = "Chromium" })

-- Code editors
hl.bind("Ctrl + Super + U", hl.dsp.exec_cmd("code"), { description = "VS Code" })
hl.bind("Ctrl + Super + X", hl.dsp.exec_cmd("subl"), { description = "Sublime Text" })
hl.bind("Ctrl + Shift + Super + C", hl.dsp.exec_cmd("jetbrains-toolbox"), { description = "JetBrains Toolbox" })
hl.bind("Ctrl + Shift + Alt + Super + C", hl.dsp.exec_cmd("jetbrains-toolbox"), { description = "JetBrains Toolbox" })

-- Calculator
hl.bind("Ctrl + Super + 3", hl.dsp.exec_cmd("~/.local/bin/wofi-calc"), { description = "Calculator" })
hl.bind("XF86Calculator", hl.dsp.exec_cmd("~/.local/bin/wofi-calc"), { description = "Calculator" })

-- Settings
hl.bind("Ctrl + Super + comma", hl.dsp.exec_cmd("quickshell -p ~/.config/quickshell/ii/settings.qml"), { description = "QuickShell settings" })

-------------------------------------------------------------------------------
-- KEYBINDS: Window Actions
-------------------------------------------------------------------------------

hl.bind("Ctrl + Super + Period", hl.dsp.exec_cmd("pkill fuzzel || ~/.local/bin/fuzzel-emoji"), { description = "Emoji picker" })
hl.bind("Alt + F4", hl.dsp.window.close(), { description = "Kill active window" })
hl.bind("Ctrl + Alt + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind("Ctrl + Alt + Q", hl.dsp.exec_cmd("hyprctl kill"), { description = "Hyprctl kill" })

-------------------------------------------------------------------------------
-- KEYBINDS: Screenshot & Recording
-------------------------------------------------------------------------------

hl.bind("Ctrl + Shift + 4", hl.dsp.exec_cmd('grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" - | wl-copy'), { description = "Screenshot region >> clipboard" })
hl.bind("Ctrl + Shift + 5", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/record.sh"), { description = "Record region (no sound)" })
hl.bind("Ctrl + Alt + 5", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/record --sound"), { description = "Record region (with sound)" })
hl.bind("Ctrl + Shift + Alt + 5", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/record.sh --fullscreen-sound"), { description = "Record fullscreen (with sound)" })
hl.bind("Super + Shift + Alt + mouse:273", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/ai/primary-buffer-query.sh"), { description = "AI summary for selected text" })
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true, description = "Screenshot >> clipboard" })
hl.bind("Ctrl + Alt + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Color picker" })
hl.bind("Super + Alt + Space", hl.dsp.exec_cmd("cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl"), { description = "Clipboard history paste" })
hl.bind("Ctrl + Alt + V", hl.dsp.exec_cmd("cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl"), { description = "Clipboard history paste (alt)" })

-------------------------------------------------------------------------------
-- KEYBINDS: Text Recognition (OCR)
-------------------------------------------------------------------------------

hl.bind("Ctrl + Shift + Super + S", hl.dsp.exec_cmd('grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract "tmp.png" - | wl-copy && rm "tmp.png"'), { description = "OCR region >> clipboard" })
hl.bind("Ctrl + Shift + T", hl.dsp.exec_cmd('grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract -l eng "tmp.png" - | wl-copy && rm "tmp.png"'), { description = "OCR region (English) >> clipboard" })

-------------------------------------------------------------------------------
-- KEYBINDS: Media Controls
-------------------------------------------------------------------------------

hl.bind("Ctrl + Shift + N", hl.dsp.exec_cmd('playerctl next || playerctl position `bc <<< "100 * $(playerctl metadata mpris:length) / 1000000 / 100"`'), { description = "Next track" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("Ctrl + Shift + B", hl.dsp.exec_cmd("playerctl previous"), { description = "Previous track" })
hl.bind("Ctrl + Shift + P", hl.dsp.exec_cmd("playerctl play-pause"), { description = "Play/Pause" })

-------------------------------------------------------------------------------
-- KEYBINDS: System Actions
-------------------------------------------------------------------------------

hl.bind("Ctrl + Super + L", hl.dsp.exec_cmd("hyprlock"), { description = "Lock screen" })

-------------------------------------------------------------------------------
-- KEYBINDS: Quickshell Interface
-------------------------------------------------------------------------------

-- Quickshell restart
hl.bind("Ctrl + Super + R", hl.dsp.exec_cmd("systemctl --user reload quickshell.service"), { release = true, description = "Reload QuickShell" })

-- Wallpaper
hl.bind("Ctrl + Super + T", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/colors/switchwall.sh --choose"), { description = "Choose wallpaper" })
hl.bind("Ctrl + Super + Shift + T", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/colors/switchwall.sh"), { description = "Random wallpaper" })

-- Desktop environment controls
hl.bind("Alt + Tab", hl.dsp.global("quickshell:overviewToggle"), { description = "Toggle overview" })
hl.bind("Ctrl + Space", hl.dsp.global("quickshell:overviewToggle")) -- [hidden]
hl.bind("Ctrl + B", hl.dsp.global("quickshell:sidebarLeftToggle"), { description = "Toggle left sidebar" })
hl.bind("Ctrl + N", hl.dsp.global("quickshell:sidebarRightToggle"), { description = "Toggle right sidebar" })
hl.bind("Ctrl + M", hl.dsp.global("quickshell:mediaControlsToggle"), { description = "Toggle media controls" })
hl.bind("Ctrl + comma", hl.dsp.global("quickshell:settingsToggle"), { description = "Toggle settings" })
hl.bind("Ctrl + Alt + Slash", hl.dsp.global("quickshell:cheatsheetToggle"), { description = "Toggle cheatsheet" })

-------------------------------------------------------------------------------
-- KEYBINDS: Window Management
-------------------------------------------------------------------------------

-- Swap windows
hl.bind("Ctrl + Shift + Left", hl.dsp.window.move({ direction = "l" }), { description = "Move window left" })
hl.bind("Ctrl + Shift + Right", hl.dsp.window.move({ direction = "r" }), { description = "Move window right" })
hl.bind("Ctrl + Shift + Up", hl.dsp.window.move({ direction = "u" }), { description = "Move window up" })
hl.bind("Ctrl + Shift + Down", hl.dsp.window.move({ direction = "d" }), { description = "Move window down" })

-- Move focus
hl.bind("Ctrl + Left", hl.dsp.focus({ direction = "l" }), { description = "Focus left" })
hl.bind("Ctrl + Right", hl.dsp.focus({ direction = "r" }), { description = "Focus right" })
hl.bind("Alt + Up", hl.dsp.focus({ direction = "u" }), { description = "Focus up" })
hl.bind("Alt + Down", hl.dsp.focus({ direction = "d" }), { description = "Focus down" })
hl.bind("Ctrl + BracketLeft", hl.dsp.focus({ direction = "l" })) -- [hidden]
hl.bind("Ctrl + BracketRight", hl.dsp.focus({ direction = "r" })) -- [hidden]

-------------------------------------------------------------------------------
-- KEYBINDS: Workspace Navigation
-------------------------------------------------------------------------------

hl.bind("Ctrl + Super + Right", hl.dsp.focus({ workspace = "+1" }), { description = "Next workspace" })
hl.bind("Ctrl + Super + Left", hl.dsp.focus({ workspace = "-1" }), { description = "Previous workspace" })
hl.bind("Ctrl + Super + BracketLeft", hl.dsp.focus({ workspace = "-1" })) -- [hidden]
hl.bind("Ctrl + Super + BracketRight", hl.dsp.focus({ workspace = "+1" })) -- [hidden]
hl.bind("Ctrl + Super + Up", hl.dsp.focus({ workspace = "-5" }), { description = "Jump 5 workspaces back" })
hl.bind("Ctrl + Super + Down", hl.dsp.focus({ workspace = "+5" }), { description = "Jump 5 workspaces forward" })
hl.bind("Ctrl + Page_Down", hl.dsp.focus({ workspace = "+1" }), { description = "Next workspace (PageDown)" })
hl.bind("Ctrl + Page_Up", hl.dsp.focus({ workspace = "-1" }), { description = "Previous workspace (PageUp)" })

-- Split ratio
hl.bind("Ctrl + Super + Minus", hl.dsp.layout("splitratio", -0.1), { repeating = true, description = "Decrease split ratio" })
hl.bind("Ctrl + Super + Equal", hl.dsp.layout("splitratio", 0.1), { repeating = true, description = "Increase split ratio" })
hl.bind("Ctrl + Semicolon", hl.dsp.layout("splitratio", -0.1), { repeating = true }) -- [hidden]
hl.bind("Ctrl + Apostrophe", hl.dsp.layout("splitratio", 0.1), { repeating = true }) -- [hidden]

-------------------------------------------------------------------------------
-- KEYBINDS: Window States
-------------------------------------------------------------------------------

hl.bind("Ctrl + Super + F", hl.dsp.window.fullscreen(0), { description = "Fullscreen (real)" })
hl.bind("Ctrl + Super + D", hl.dsp.window.fullscreen(1), { description = "Fullscreen (maximize)" })
hl.bind("Ctrl + Alt + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3 }), { description = "Fullscreen state toggle" })

-------------------------------------------------------------------------------
-- KEYBINDS: Workspace Switching
-------------------------------------------------------------------------------

hl.bind("Ctrl + 1", hl.dsp.focus({ workspace = "1" }), { description = "Workspace 1" })
hl.bind("Ctrl + 2", hl.dsp.focus({ workspace = "2" }), { description = "Workspace 2" })
hl.bind("Ctrl + 3", hl.dsp.focus({ workspace = "3" }), { description = "Workspace 3" })
hl.bind("Ctrl + 4", hl.dsp.focus({ workspace = "4" }), { description = "Workspace 4" })
hl.bind("Ctrl + 5", hl.dsp.focus({ workspace = "5" }), { description = "Workspace 5" })
hl.bind("Ctrl + 6", hl.dsp.focus({ workspace = "6" }), { description = "Workspace 6" })
hl.bind("Ctrl + 7", hl.dsp.focus({ workspace = "7" }), { description = "Workspace 7" })
hl.bind("Ctrl + 8", hl.dsp.focus({ workspace = "8" }), { description = "Workspace 8" })
hl.bind("Ctrl + 9", hl.dsp.focus({ workspace = "9" }), { description = "Workspace 9" })
hl.bind("Ctrl + 0", hl.dsp.focus({ workspace = "10" }), { description = "Workspace 10" })
hl.bind("Ctrl + Super + S", hl.dsp.workspace.toggle_special(""), { description = "Toggle special workspace" })
hl.bind("Alt + Tab", hl.dsp.window.cycle_next()) -- [hidden]
hl.bind("Alt + Tab", hl.dsp.window.bring_to_top()) -- [hidden]

-------------------------------------------------------------------------------
-- KEYBINDS: Move Windows to Workspace
-------------------------------------------------------------------------------

hl.bind("Ctrl + Alt + 1", hl.dsp.window.move({ workspace = "1", silent = true }), { description = "Move to workspace 1" })
hl.bind("Ctrl + Alt + 2", hl.dsp.window.move({ workspace = "2", silent = true }), { description = "Move to workspace 2" })
hl.bind("Ctrl + Alt + 3", hl.dsp.window.move({ workspace = "3", silent = true }), { description = "Move to workspace 3" })
hl.bind("Ctrl + Alt + 4", hl.dsp.window.move({ workspace = "4", silent = true }), { description = "Move to workspace 4" })
hl.bind("Ctrl + Alt + 5", hl.dsp.window.move({ workspace = "5", silent = true }), { description = "Move to workspace 5" })
hl.bind("Ctrl + Alt + 6", hl.dsp.window.move({ workspace = "6", silent = true }), { description = "Move to workspace 6" })
hl.bind("Ctrl + Alt + 7", hl.dsp.window.move({ workspace = "7", silent = true }), { description = "Move to workspace 7" })
hl.bind("Ctrl + Alt + 8", hl.dsp.window.move({ workspace = "8", silent = true }), { description = "Move to workspace 8" })
hl.bind("Ctrl + Alt + 9", hl.dsp.window.move({ workspace = "9", silent = true }), { description = "Move to workspace 9" })
hl.bind("Ctrl + Alt + 0", hl.dsp.window.move({ workspace = "10", silent = true }), { description = "Move to workspace 10" })
hl.bind("Ctrl + Alt + S", hl.dsp.window.move({ workspace = "special", silent = true }), { description = "Move to special workspace" })

-------------------------------------------------------------------------------
-- KEYBINDS: Mouse Controls
-------------------------------------------------------------------------------

-- Mouse workspace scrolling
hl.bind("Ctrl + mouse_up", hl.dsp.focus({ workspace = "+1" })) -- [hidden]
hl.bind("Ctrl + mouse_down", hl.dsp.focus({ workspace = "-1" })) -- [hidden]
hl.bind("Ctrl + Super + mouse_up", hl.dsp.focus({ workspace = "+1" })) -- [hidden]
hl.bind("Ctrl + Super + mouse_down", hl.dsp.focus({ workspace = "-1" })) -- [hidden]

-- Mouse window controls
hl.bind("Ctrl + mouse:273", hl.dsp.window.resize(), { mouse = true }) -- [hidden]
hl.bind("Ctrl + Super + mouse:273", hl.dsp.window.resize(), { mouse = true }) -- [hidden]
hl.bind("mouse:274", hl.dsp.window.drag(), { mouse = true }) -- [hidden]
hl.bind("Ctrl + Super + Z", hl.dsp.window.drag(), { mouse = true, description = "Move window (keyboard)" })
hl.bind("Ctrl + Super + Backslash", hl.dsp.window.resize({ x = 640, y = 480, exact = true }), { description = "Resize to 640x480" })

-------------------------------------------------------------------------------
-- EXEC-ONCE: Autostart (esnixi-specific)
-------------------------------------------------------------------------------

hl.on("hyprland.start", function()
    -- Cursor theme
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")

    -- OpenRGB lighting
    hl.exec_cmd("sleep 3 && openrgb -p default.orp")

    -- QuickShell desktop environment
    hl.exec_cmd("systemctl --user start quickshell.service")

    -- Hyte touch interface on DP-3
    hl.exec_cmd("[workspace name:touch silent] hyte-touch-interface")

    -- Clipboard history
    hl.exec_cmd("wl-paste --watch cliphist store")

    -- Geoclue agent
    hl.exec_cmd("~/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")

    -- Authentication
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1 || /usr/libexec/polkit-kde-authentication-agent-1  || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1")

    -- Idle daemon
    hl.exec_cmd("hypridle")

    -- Touchpad gestures
    hl.exec_cmd("touchegg")

    -- D-Bus environment
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Hyprland plugins
    hl.exec_cmd("hyprpm list &>/dev/null && hyprpm reload")

    -- Audio effects
    hl.exec_cmd("easyeffects --gapplication-service")
end)
