-- nixberry host-specific Hyprland overrides
-- Parallels Desktop aarch64 VM — single monitor, no HYTE display, no WinApps

-------------------------------------------------------------------------------
-- MONITORS
-------------------------------------------------------------------------------

-- Let Parallels auto-detect (single virtual display)
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
-- AUTOSTART (nixberry-specific)
-------------------------------------------------------------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start quickshell.service")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
