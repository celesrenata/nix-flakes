# Hyprland configuration for nixberry (Parallels Desktop aarch64 VM)
# Uses Lua config (Hyprland 0.55+) with standard Super-key keybinds from dots-hyprland.
# No DP-3 touch display, no HYTE, no WinApps — single monitor VM.
{ inputs, lib, pkgs, config, ... }:

{
  imports = [
    inputs.ags.homeManagerModules.default
    inputs.dots-hyprland.homeManagerModules.default
  ];

  # dots-hyprland configuration for nixberry
  programs.dots-hyprland = {
    enable = true;
    source = pkgs.dots-hyprland-source-filtered;  # Has Lua configs from end-4-flakes
    packageSet = "essential";
    mode = "hybrid";

    touchegg.enable = lib.mkForce false;
    configuration.copyMiscConfig = lib.mkForce true;
    configuration.applications.foot.enable = lib.mkForce false;
    configuration.applications.kitty.enable = lib.mkForce false;
    configuration.applications.fuzzel.enable = lib.mkForce false;
    configuration.copyFishConfig = lib.mkForce false;

    # Use Lua config (0.55+) — base files come from end-4-flakes
    overrides.useLuaConfig = true;
  };

  # Prevent HM from managing icons dir — Steam needs to write here
  home.file.".local/share/icons".enable = false;

  # Override default keybinds with stub (nixberry uses esnixi's Ctrl+Super scheme in host.lua)
  xdg.configFile."hypr/hyprland/keybinds.lua".source = lib.mkForce ../vm/hypr-lua/keybinds-stub.lua;
  # Host-specific config (loaded last via pcall in hyprland.lua)
  home.file.".config/hypr/hyprland/host.lua".source = ../vm/hypr-lua/nixberry.lua;
}
