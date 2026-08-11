-- nixberry host-specific Hyprland overrides
-- Parallels Desktop aarch64 VM — single monitor, no HYTE display, no WinApps
-- Autostart is handled by execs.lua (from dots-hyprland)
-- Keybinds use esnixi's Ctrl+Super scheme (default keybinds.lua is stubbed out)

-------------------------------------------------------------------------------
-- MONITORS
-------------------------------------------------------------------------------

-- Parallels virtual display — use a good resolution (Retina-equivalent)
hl.monitor({ output = "Virtual-1", mode = "2560x1600@60", position = "auto", scale = "1" })
-- Fallback for any other output
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })

-------------------------------------------------------------------------------
-- ENVIRONMENT VARIABLES
-------------------------------------------------------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("OLLAMA_HOST", "http://10.1.1.12:2701")
hl.env("TERMINAL", "foot")

-------------------------------------------------------------------------------
-- INPUT CONFIGURATION
-------------------------------------------------------------------------------

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,

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
-- MISC
-------------------------------------------------------------------------------

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = -1,
    },
})

-------------------------------------------------------------------------------
-- WINDOW RULES
-------------------------------------------------------------------------------

-- Suppress maximize for all windows
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

-------------------------------------------------------------------------------
-- SESSION TARGET (ensures quickshell.service starts via systemd)
-------------------------------------------------------------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprland-session.target")
end)

-------------------------------------------------------------------------------
-- KEYBINDS: Voice Dictation
-------------------------------------------------------------------------------

hl.bind("Ctrl + H", hl.dsp.global("quickshell:dictationTap"), { description = "Shell: Voice dictation" })

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
hl.bind("Ctrl + Super + M", hl.dsp.exec_cmd("tidal-hifi"), { description = "Apps: Tidal HiFi" })
hl.bind("Ctrl + Shift + Super + M", hl.dsp.exec_cmd("env -u NIXOS_OZONE_WL cider --use-gl=desktop"), { description = "Apps: Cider" })
hl.bind("Ctrl + Alt + Super + M", hl.dsp.exec_cmd("spotify"), { description = "Apps: Spotify" })

-- Discord
hl.bind("Ctrl + Super + I", hl.dsp.exec_cmd("discord"), { description = "Apps: Discord" })

-- Terminal (Foot)
hl.bind("Ctrl + Super + G", hl.dsp.exec_cmd("foot"), { description = "Apps: Foot terminal" })
hl.bind("Ctrl + Shift + Super + T", hl.dsp.exec_cmd("foot sleep 0.01 && nmtui"), { description = "Apps: Network manager TUI" })

-- File managers
hl.bind("Ctrl + Super + J", hl.dsp.exec_cmd("thunar"), { description = "Apps: Thunar" })
hl.bind("Ctrl + Shift + Super + J", hl.dsp.exec_cmd("nautilus"), { description = "Apps: Nautilus" })

-- Browsers
hl.bind("Ctrl + Super + B", hl.dsp.exec_cmd("firefox"), { description = "Apps: Firefox" })
hl.bind("Ctrl + Shift + Super + B", hl.dsp.exec_cmd("chromium"), { description = "Apps: Chromium" })

-- Code editors
hl.bind("Ctrl + Super + C", hl.dsp.exec_cmd("code"), { description = "Apps: VS Code" })
hl.bind("Ctrl + Super + X", hl.dsp.exec_cmd("subl"), { description = "Apps: Sublime Text" })
hl.bind("Ctrl + Shift + Super + C", hl.dsp.exec_cmd("jetbrains-toolbox"), { description = "Apps: JetBrains Toolbox" })

-- Calculator
hl.bind("Ctrl + Super + 3", hl.dsp.exec_cmd("~/.local/bin/wofi-calc"), { description = "Apps: Calculator" })
hl.bind("XF86Calculator", hl.dsp.exec_cmd("~/.local/bin/wofi-calc"), { description = "Apps: Calculator" })

-- Settings
hl.bind("Ctrl + Super + comma", hl.dsp.exec_cmd("quickshell -p ~/.config/quickshell/ii/settings.qml"), { description = "Apps: QuickShell settings" })

-------------------------------------------------------------------------------
-- KEYBINDS: Window Actions
-------------------------------------------------------------------------------

hl.bind("Ctrl + Super + Period", hl.dsp.exec_cmd("pkill fuzzel || ~/.local/bin/fuzzel-emoji"), { description = "Utilities: Emoji picker" })
hl.bind("Alt + F4", hl.dsp.window.close(), { description = "Window: Close" })
hl.bind("Ctrl + Alt + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Toggle floating" })
hl.bind("Ctrl + Alt + Q", hl.dsp.exec_cmd("hyprctl kill"), { description = "Window: Force kill" })

-------------------------------------------------------------------------------
-- KEYBINDS: Screenshot & Recording
-------------------------------------------------------------------------------

hl.bind("Ctrl + Shift + 4", hl.dsp.exec_cmd('grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" - | wl-copy'), { description = "Utilities: Screenshot region >> clipboard" })
hl.bind("Ctrl + Shift + 5", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/record.sh"), { description = "Utilities: Record region" })
hl.bind("Ctrl + Alt + 5", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/record --sound"), { description = "Utilities: Record region (sound)" })
hl.bind("Ctrl + Shift + Alt + 5", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/record.sh --fullscreen-sound"), { description = "Utilities: Record fullscreen (sound)" })
hl.bind("Super + Shift + Alt + mouse:273", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/ai/primary-buffer-query.sh"), { description = "Utilities: AI summary" })
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"), { locked = true, description = "Utilities: Screenshot >> clipboard" })
hl.bind("Ctrl + Alt + C", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Utilities: Color picker" })
hl.bind("Super + Alt + Space", hl.dsp.exec_cmd("cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl"), { description = "Utilities: Clipboard history" })
hl.bind("Ctrl + Alt + V", hl.dsp.exec_cmd("cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl"), { description = "Utilities: Clipboard history (alt)" })

-------------------------------------------------------------------------------
-- KEYBINDS: Text Recognition (OCR)
-------------------------------------------------------------------------------

hl.bind("Ctrl + Shift + Super + S", hl.dsp.exec_cmd('grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract "tmp.png" - | wl-copy && rm "tmp.png"'), { description = "Utilities: OCR >> clipboard" })
hl.bind("Ctrl + Shift + T", hl.dsp.exec_cmd('grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract -l eng "tmp.png" - | wl-copy && rm "tmp.png"'), { description = "Utilities: OCR English >> clipboard" })

-------------------------------------------------------------------------------
-- KEYBINDS: Media Controls
-------------------------------------------------------------------------------

hl.bind("Ctrl + Shift + N", hl.dsp.exec_cmd('playerctl next || playerctl position `bc <<< "100 * $(playerctl metadata mpris:length) / 1000000 / 100"`'), { description = "Media: Next track" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("Ctrl + Shift + B", hl.dsp.exec_cmd("playerctl previous"), { description = "Media: Previous track" })
hl.bind("Ctrl + Shift + P", hl.dsp.exec_cmd("playerctl play-pause"), { description = "Media: Play/Pause" })

-------------------------------------------------------------------------------
-- KEYBINDS: System Actions
-------------------------------------------------------------------------------

hl.bind("Ctrl + Super + L", hl.dsp.exec_cmd("hyprlock"), { description = "Session: Lock" })

-------------------------------------------------------------------------------
-- KEYBINDS: Quickshell Interface
-------------------------------------------------------------------------------

-- Quickshell restart
hl.bind("Ctrl + Super + R", hl.dsp.exec_cmd("systemctl --user reload quickshell.service"), { release = true, description = "Shell: Reload QuickShell" })

-- Wallpaper
hl.bind("Ctrl + Super + T", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/colors/switchwall.sh --choose"), { description = "Session: Choose wallpaper" })
hl.bind("Ctrl + Super + Shift + T", hl.dsp.exec_cmd("~/.config/quickshell/ii/scripts/colors/switchwall.sh"), { description = "Session: Random wallpaper" })

-- Desktop environment controls
hl.bind("Alt + Tab", hl.dsp.global("quickshell:overviewToggle"), { description = "Shell: Toggle overview" })
hl.bind("Ctrl + Space", hl.dsp.global("quickshell:overviewToggle")) -- [hidden]
hl.bind("Ctrl + B", hl.dsp.global("quickshell:sidebarLeftToggle"), { description = "Shell: Left sidebar" })
hl.bind("Ctrl + N", hl.dsp.global("quickshell:sidebarRightToggle"), { description = "Shell: Right sidebar" })
hl.bind("Ctrl + M", hl.dsp.global("quickshell:mediaControlsToggle"), { description = "Shell: Media controls" })
hl.bind("Ctrl + comma", hl.dsp.global("quickshell:settingsToggle"), { description = "Shell: Settings" })
hl.bind("Ctrl + Alt + Slash", hl.dsp.global("quickshell:cheatsheetToggle"), { description = "Shell: Cheatsheet" })

-------------------------------------------------------------------------------
-- KEYBINDS: Window Management
-------------------------------------------------------------------------------

-- Swap windows
hl.bind("Ctrl + Shift + Left", hl.dsp.window.move({ direction = "l" }), { description = "Window: Move left" })
hl.bind("Ctrl + Shift + Right", hl.dsp.window.move({ direction = "r" }), { description = "Window: Move right" })
hl.bind("Ctrl + Shift + Up", hl.dsp.window.move({ direction = "u" }), { description = "Window: Move up" })
hl.bind("Ctrl + Shift + Down", hl.dsp.window.move({ direction = "d" }), { description = "Window: Move down" })

-- Move focus
hl.bind("Ctrl + Left", hl.dsp.focus({ direction = "l" }), { description = "Window: Focus left" })
hl.bind("Ctrl + Right", hl.dsp.focus({ direction = "r" }), { description = "Window: Focus right" })
hl.bind("Alt + Up", hl.dsp.focus({ direction = "u" }), { description = "Window: Focus up" })
hl.bind("Alt + Down", hl.dsp.focus({ direction = "d" }), { description = "Window: Focus down" })
hl.bind("Ctrl + BracketLeft", hl.dsp.focus({ direction = "l" })) -- [hidden]
hl.bind("Ctrl + BracketRight", hl.dsp.focus({ direction = "r" })) -- [hidden]

-------------------------------------------------------------------------------
-- KEYBINDS: Workspace Navigation
-------------------------------------------------------------------------------

hl.bind("Ctrl + Super + Right", hl.dsp.focus({ workspace = "+1" }), { description = "Workspace: Next" })
hl.bind("Ctrl + Super + Left", hl.dsp.focus({ workspace = "-1" }), { description = "Workspace: Previous" })
hl.bind("Ctrl + Super + BracketLeft", hl.dsp.focus({ workspace = "-1" })) -- [hidden]
hl.bind("Ctrl + Super + BracketRight", hl.dsp.focus({ workspace = "+1" })) -- [hidden]
hl.bind("Ctrl + Super + Up", hl.dsp.focus({ workspace = "-5" }), { description = "Workspace: Jump 5 back" })
hl.bind("Ctrl + Super + Down", hl.dsp.focus({ workspace = "+5" }), { description = "Workspace: Jump 5 forward" })
hl.bind("Ctrl + Page_Down", hl.dsp.focus({ workspace = "+1" }), { description = "Workspace: Next (PageDown)" })
hl.bind("Ctrl + Page_Up", hl.dsp.focus({ workspace = "-1" }), { description = "Workspace: Previous (PageUp)" })

-- Split ratio
hl.bind("Ctrl + Super + Minus", hl.dsp.layout("splitratio", -0.1), { repeating = true, description = "Window: Decrease split ratio" })
hl.bind("Ctrl + Super + Equal", hl.dsp.layout("splitratio", 0.1), { repeating = true, description = "Window: Increase split ratio" })
hl.bind("Ctrl + Semicolon", hl.dsp.layout("splitratio", -0.1), { repeating = true }) -- [hidden]
hl.bind("Ctrl + Apostrophe", hl.dsp.layout("splitratio", 0.1), { repeating = true }) -- [hidden]

-------------------------------------------------------------------------------
-- KEYBINDS: Window States
-------------------------------------------------------------------------------

hl.bind("Ctrl + Super + F", hl.dsp.window.fullscreen(0), { description = "Window: Fullscreen" })
hl.bind("Ctrl + Super + D", hl.dsp.window.fullscreen(1), { description = "Window: Maximize" })
hl.bind("Ctrl + Alt + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 3 }), { description = "Window: Fullscreen spoof" })

-------------------------------------------------------------------------------
-- KEYBINDS: Workspace Switching
-------------------------------------------------------------------------------

hl.bind("Ctrl + 1", hl.dsp.focus({ workspace = "1" }), { description = "Workspace: 1" })
hl.bind("Ctrl + 2", hl.dsp.focus({ workspace = "2" }), { description = "Workspace: 2" })
hl.bind("Ctrl + 3", hl.dsp.focus({ workspace = "3" }), { description = "Workspace: 3" })
hl.bind("Ctrl + 4", hl.dsp.focus({ workspace = "4" }), { description = "Workspace: 4" })
hl.bind("Ctrl + 5", hl.dsp.focus({ workspace = "5" }), { description = "Workspace: 5" })
hl.bind("Ctrl + 6", hl.dsp.focus({ workspace = "6" }), { description = "Workspace: 6" })
hl.bind("Ctrl + 7", hl.dsp.focus({ workspace = "7" }), { description = "Workspace: 7" })
hl.bind("Ctrl + 8", hl.dsp.focus({ workspace = "8" }), { description = "Workspace: 8" })
hl.bind("Ctrl + 9", hl.dsp.focus({ workspace = "9" }), { description = "Workspace: 9" })
hl.bind("Ctrl + 0", hl.dsp.focus({ workspace = "10" }), { description = "Workspace: 10" })
hl.bind("Ctrl + Super + S", hl.dsp.workspace.toggle_special(""), { description = "Workspace: Toggle special" })
hl.bind("Alt + Tab", hl.dsp.window.cycle_next()) -- [hidden]
hl.bind("Alt + Tab", hl.dsp.window.bring_to_top()) -- [hidden]

-------------------------------------------------------------------------------
-- KEYBINDS: Move Windows to Workspace
-------------------------------------------------------------------------------

hl.bind("Ctrl + Alt + 1", hl.dsp.window.move({ workspace = "1", silent = true }), { description = "Workspace: Move to 1" })
hl.bind("Ctrl + Alt + 2", hl.dsp.window.move({ workspace = "2", silent = true }), { description = "Workspace: Move to 2" })
hl.bind("Ctrl + Alt + 3", hl.dsp.window.move({ workspace = "3", silent = true }), { description = "Workspace: Move to 3" })
hl.bind("Ctrl + Alt + 4", hl.dsp.window.move({ workspace = "4", silent = true }), { description = "Workspace: Move to 4" })
hl.bind("Ctrl + Alt + 5", hl.dsp.window.move({ workspace = "5", silent = true }), { description = "Workspace: Move to 5" })
hl.bind("Ctrl + Alt + 6", hl.dsp.window.move({ workspace = "6", silent = true }), { description = "Workspace: Move to 6" })
hl.bind("Ctrl + Alt + 7", hl.dsp.window.move({ workspace = "7", silent = true }), { description = "Workspace: Move to 7" })
hl.bind("Ctrl + Alt + 8", hl.dsp.window.move({ workspace = "8", silent = true }), { description = "Workspace: Move to 8" })
hl.bind("Ctrl + Alt + 9", hl.dsp.window.move({ workspace = "9", silent = true }), { description = "Workspace: Move to 9" })
hl.bind("Ctrl + Alt + 0", hl.dsp.window.move({ workspace = "10", silent = true }), { description = "Workspace: Move to 10" })
hl.bind("Ctrl + Alt + S", hl.dsp.window.move({ workspace = "special", silent = true }), { description = "Workspace: Move to special" })

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
hl.bind("Ctrl + Super + Z", hl.dsp.window.drag(), { mouse = true, description = "Window: Move (keyboard)" })
hl.bind("Ctrl + Super + Backslash", hl.dsp.window.resize({ x = 640, y = 480, exact = true }), { description = "Window: Resize to 640x480" })
