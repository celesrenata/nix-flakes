-- nixberry host-specific Hyprland overrides
-- Parallels Desktop aarch64 VM — single monitor, no HYTE display, no WinApps
-- Autostart is handled by execs.lua (from dots-hyprland)

-------------------------------------------------------------------------------
-- MONITORS
-------------------------------------------------------------------------------

-- Parallels virtual display — use a good resolution (Retina-equivalent)
-- Available: up to 4096x2160, 2560x1600, 1920x1200, etc.
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
