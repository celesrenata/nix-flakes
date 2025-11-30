# Hyprland configuration for macland (MacBook T2)
{ inputs, lib, pkgs, pkgs-unstable, config, ... }:

{
  imports = [ 
    inputs.ags.homeManagerModules.default
    inputs.dots-hyprland.homeManagerModules.default
  ];

  # dots-hyprland configuration for macland
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
      # Hyprland configuration for macland (MacBook T2)
      
      # Monitor configuration - MacBook specific resolution
      monitor=,1920x1200@60,auto,1
      
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
      
      # Quickshell restart
      bindr = $Primary$Secondary, R, exec, systemctl --user reload quickshell.service
      
      # Wallpaper selection
      bind = CTRL SUPER, T, exec, ~/.config/quickshell/ii/scripts/colors/switchwall-wrapper.sh --choose
      bind = CTRL SUPER SHIFT, T, exec, ~/.config/quickshell/ii/scripts/colors/switchwall-wrapper.sh
      
      # Desktop environment controls
      bind = $Alternate, Tab, exec, hyprctl dispatch global quickshell:overviewToggle
      bind = $Secondary, Space, exec, hyprctl dispatch global quickshell:overviewToggle
      bind = $Secondary, B, exec, hyprctl dispatch global quickshell:sidebarLeftToggle
      bind = $Secondary, N, exec, hyprctl dispatch global quickshell:sidebarRightToggle
      bind = $Secondary, M, exec, hyprctl dispatch global quickshell:mediaControlsToggle
      bind = $Secondary, Comma, exec, hyprctl dispatch global quickshell:settingsToggle
      bind = $Secondary$Alternate, Slash, exec, hyprctl dispatch global quickshell:cheatsheetToggle
    '';
  };
}
