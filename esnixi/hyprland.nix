# Hyprland configuration for esnixi (desktop)
{ inputs, lib, pkgs, pkgs-unstable, config, ... }:

{
  imports = [ 
    inputs.ags.homeManagerModules.default
    inputs.dots-hyprland.homeManagerModules.default
  ];

  # dots-hyprland configuration for esnixi
  programs.dots-hyprland = {
    enable = true;
    source = inputs.dots-hyprland-source;
    packageSet = "essential";
    mode = "hybrid";
    
    touchegg.enable = lib.mkForce false;
    configuration.copyMiscConfig = lib.mkForce true;
    configuration.applications.foot.enable = lib.mkForce false;
    configuration.applications.kitty.enable = lib.mkForce false;
    configuration.applications.fuzzel.enable = lib.mkForce false;
    configuration.copyFishConfig = lib.mkForce false;
    
    overrides.hyprlandConf = ''
      # Hyprland configuration for esnixi (desktop)
      
      # Monitor configuration - disable DP-3 for separate Hyte session
      monitor=,preferred,auto,1
      monitor=DP-3,disable
      
      # Environment variables
      env = XCURSOR_SIZE,24
      env = QT_QPA_PLATFORMTHEME,qt5ct
      env = OLLAMA_HOST,http://10.1.1.12:2701
      env = QT_IM_MODULE, fcitx
      env = XMODIFIERS, @im=fcitx
      env = SDL_IM_MODULE, fcitx
      env = GLFW_IM_MODULE, ibus
      env = INPUT_METHOD, fcitx
      env = ELECTRON_OZONE_PLATFORM_HINT,auto
      env = QT_QPA_PLATFORM, wayland
      env = QT_QPA_PLATFORMTHEME, kde
      env = XDG_MENU_PREFIX, plasma-
      env = TERMINAL,foot
      
      # Rest of config...
    '';
  };
}
