# Hyprland configuration for esnixi (desktop)
{ inputs, lib, pkgs, config, ... }:

{
  imports = [ 
    inputs.ags.homeManagerModules.default
    inputs.dots-hyprland.homeManagerModules.default
    ../home/system/hyte-touch.nix
    ../home/system/rgb-gradient.nix
  ];

  # dots-hyprland configuration for esnixi
  programs.dots-hyprland = {
    enable = true;
    source = pkgs.dots-hyprland-source-filtered;  # Use DP-3 filtered version
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

  # esnixi host config — provides keybinds + DP-3/Hyte touch + custom autostart
  # Override default keybinds (esnixi uses its own Ctrl+Shift+Super scheme)
  home.file.".config/hypr/hyprland/keybinds.lua" = { text = "-- esnixi: keybinds provided by host.lua\n"; force = true; };
  # Host-specific config (loaded last via pcall in hyprland.lua)
  home.file.".config/hypr/hyprland/host.lua".source = ../esnixi/hypr-lua/hyprland/esnixi.lua;

  # Hyprland plugins (disabled until hyprland-plugins is updated for 0.56)
  # wayland.windowManager.hyprland.plugins = [
  #   inputs.hyprland-plugins.packages.${pkgs.system}.hyprbars
  # ];
}
