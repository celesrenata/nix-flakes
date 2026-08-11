-- nixbox host-specific Hyprland overrides
-- VirtualBox/VMware x86_64 VM — single monitor, no HYTE display, no WinApps
-- Autostart is handled by execs.lua (from dots-hyprland)

-------------------------------------------------------------------------------
-- MONITORS
-------------------------------------------------------------------------------

-- VirtualBox/VMware virtual display
-- VirtualBox VMSVGA: reports as "Virtual-1"
-- VMware: reports as "Virtual-1" or the vmwgfx output name
hl.monitor({ output = "Virtual-1", mode = "1920x1080@60", position = "auto", scale = "1" })
-- Fallback for any other output
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })

-------------------------------------------------------------------------------
-- ENVIRONMENT VARIABLES
-------------------------------------------------------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("OLLAMA_HOST", "http://10.1.1.12:2701")
hl.env("TERMINAL", "foot")

-- VirtualBox/VMware specific — help with Wayland compositing in VMs
hl.env("WLR_NO_HARDWARE_CURSORS", "1")
hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "1")

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
