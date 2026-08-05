-- Hyprland 0.55+ Lua configuration entry point
-- Sub-modules are loaded in dependency order from hyprland/

require("hyprland/env")
require("hyprland/general")
require("hyprland/colors")
require("hyprland/rules")
require("hyprland/execs")
-- keybinds: loaded per-host (esnixi.lua provides its own keybind scheme)
require("hyprland/esnixi")
