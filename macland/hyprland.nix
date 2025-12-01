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
      
      # KEYBIND VARIABLES - Must be defined FIRST before any bindings
      $Primary = Super
      $Secondary = Control
      $Tertiary = Shift
      $Alternate = Alt
      
      # Monitor configuration - MacBook Retina display at native resolution
      monitor=,preferred,auto,1.5
      
      # Start hyprland-session.target for systemd services
      exec-once = systemctl --user start hyprland-session.target
      
      # General configuration
      general {
          gaps_in = 4
          gaps_out = 7
          border_size = 2
          col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
          col.inactive_border = rgba(595959aa)
          layout = dwindle
          allow_tearing = false
      }
      
      # Input configuration
      input {
          kb_layout = us
          follow_mouse = 1
          
          touchpad {
              natural_scroll = yes
              tap-to-click = yes
              disable_while_typing = yes
              clickfinger_behavior = 1
              middle_button_emulation = yes
          }
          
          sensitivity = 0
      }
      
      # Decoration
      decoration {
          rounding = 16
          
          blur {
              enabled = true
              size = 3
              passes = 1
          }
          
          shadow {
              enabled = yes
              range = 4
              render_power = 3
              color = rgba(1a1a1aee)
          }
      }
      
      # Gestures
      gestures {
          gesture = 3, horizontal, workspace
      }
      
      # Animations
      animations {
          enabled = yes
          
          bezier = myBezier, 0.05, 0.9, 0.1, 1.05
          
          animation = windows, 1, 7, myBezier
          animation = windowsOut, 1, 7, default, popin 80%
          animation = border, 1, 10, default
          animation = borderangle, 1, 8, default
          animation = fade, 1, 7, default
          animation = workspaces, 1, 6, default
      }
      
      # Dwindle layout
      dwindle {
          pseudotile = yes
          preserve_split = yes
      }
      
      # Master layout
      master {
          new_status = master
      }
      
      # Misc settings
      misc {
          disable_hyprland_logo = true
          disable_splash_rendering = true
          mouse_move_enables_dpms = false
          key_press_enables_dpms = false
          force_default_wallpaper = -1
      }
      
      # Window rules
      windowrulev2 = suppressevent maximize, class:.*
      windowrulev2 = center, class:^(discord)$
      windowrulev2 = size 1200 1000, class:^(discord)$, floating:1
      
      # Environment variables
      env = XCURSOR_THEME,Bibata-Modern-Classic
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
      
      # Import all keybindings from shared config
      ${builtins.readFile ./keybindings.conf}
    '';
  };
}
