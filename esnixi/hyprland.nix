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
    source = pkgs.dots-hyprland-source-filtered;  # Use DP-3 filtered version
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
      
      # Monitor configuration - enable DP-3 for isolated Hyte touch interface
      monitor=,preferred,auto,1
      monitor=DP-3,2560x682,auto,1,transform,3
      
      # Start cursor barrier script to prevent mouse from entering DP-3
      exec-once = ${pkgs.hyte-touch-infinite-flakes}/scripts/cursor-barrier.sh
      
      # Hyte Touch Display Configuration - Isolate DP-3
      workspace = name:touch, monitor:DP-3, default:true
      workspace = name:touch, gapsin:0, gapsout:0, border:false

      # Prevent regular input devices from affecting touch workspace
      bind = , mouse:272, exec, [[ $(hyprctl activeworkspace | grep "touch") ]] || hyprctl dispatch mouse:272
      bind = , mouse:273, exec, [[ $(hyprctl activeworkspace | grep "touch") ]] || hyprctl dispatch mouse:273
      
      # Prevent mouse cursor from crossing to DP-3 and enable direct touch
      misc {
          disable_hyprland_logo = true
          disable_splash_rendering = true
          mouse_move_enables_dpms = false
          key_press_enables_dpms = false
      }

      # Isolate DP-3 with workspace rules
      workspace = DP-3,1
      
      # Prevent cursor from warping to DP-3
      cursor {
          no_warps = true
          hide_on_touch = true
      }
      
      # Window rules to lock touch interface to DP-3
      windowrulev2 = workspace name:touch, title:^(hyte-touch-interface)$
      windowrulev2 = monitor DP-3, title:^(hyte-touch-interface)$
      windowrulev2 = fullscreen, title:^(hyte-touch-interface)$
      


      # Map Hyte touchpad specifically to DP-3
      device {
          name = ilitek-------ilitek-touch
          output = DP-3
          enabled = true
          transform = 3
      }

      # Disable cursor on DP-3 for direct touch interaction
      cursor {
          no_warps = true
          hide_on_touch = true
          inactive_timeout = 0
      }

      # Touch-specific input configuration
      input {
          touchpad {
              disable_while_typing = false
              tap-to-click = true
              drag_lock = false
          }
          touchdevice {
              output = DP-3
              transform = 3
          }
      }
      
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
      
      # Input configuration
      input {
          kb_layout = us
          kb_variant =
          kb_model =
          kb_options =
          kb_rules =
          
          follow_mouse = 1
          
          touchpad {
              natural_scroll = yes
              tap-to-click = yes
              disable_while_typing = yes
              clickfinger_behavior = 1
              middle_button_emulation = yes
          }
          
          sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
      }

      # General configuration
      general {
          # Gaps and border
          gaps_in = 4
          gaps_out = 7
          border_size = 2
          col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
          col.inactive_border = rgba(595959aa)
          
          # Layout
          layout = dwindle
          allow_tearing = false
      }

      decoration {
          # Rounding and blur
          rounding = 16
          
          blur {
              enabled = true
              size = 3
              passes = 1
          }
          
          # Updated shadow syntax for newer Hyprland versions
          shadow {
              enabled = yes
              range = 4
              render_power = 3
              color = rgba(1a1a1aee)
          }
      }

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

      dwindle {
          pseudotile = yes
          preserve_split = yes
      }

      master {
          new_status = master
      }

      # Gestures
      gestures {
          workspace_swipe = true
          workspace_swipe_distance = 700
          workspace_swipe_fingers = 3
          workspace_swipe_min_fingers = false
          workspace_swipe_cancel_ratio = 0.2
          workspace_swipe_min_speed_to_force = 5
          workspace_swipe_direction_lock = true
          workspace_swipe_direction_lock_threshold = 10
          workspace_swipe_create_new = true
      }

      misc {
          force_default_wallpaper = -1
      }

      # Window rules
      windowrulev2 = suppressevent maximize, class:.*

      # KEYBIND VARIABLES - Fixed with proper definitions
      $Primary = Super
      $Secondary = Control
      $Tertiary = Shift
      $Alternate = Alt

      #+! System Controls
      # Volume
      bindl = ,XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle
      bindle=, XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindle=, XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-

      # Brightness (updated for Quickshell)
      bindle=, XF86MonBrightnessUp, exec, brightnessctl set '12.75+' && hyprctl dispatch global quickshell:osdShow
      bindle=, XF86MonBrightnessDown, exec, brightnessctl set '12.75-' && hyprctl dispatch global quickshell:osdShow

      #+! Applications
      # Music
      bind = $Primary$Secondary, M, exec, tidal-hifi
      bind = $Primary$Secondary$Tertiary, M, exec, env -u NIXOS_OZONE_WL cider --use-gl=desktop
      bind = $Primary$Secondary$Alternate, M, exec, spotify
      # Discord
      bind = $Primary$Secondary, I, exec, discord 
      # Foot
      bind = $Primary$Secondary, H, exec, foot
      bind = $Primary$Secondary$Tertiary, T, exec, foot sleep 0.01 && nmtui
      # Finders
      bind = $Primary$Secondary, J, exec, thunar
      bind = $Primary$Secondary$Tertiary, J, exec, nautilus
      # Browsers
      bind = $Primary$Secondary, B, exec, firefox
      bind = $Primary$Secondary$Tertiary, B, exec, chromium 
      # Code editors
      bind = $Primary$Secondary, U, exec, code
      bind = $Primary$Secondary, X, exec, subl
      bind = $Primary$Secondary, C, exec, code
      bind = $Primary$Secondary$Tertiary, C, exec, jetbrains-toolbox
      # Calculator
      bind = $Primary$Secondary, 3, exec, ~/.local/bin/wofi-calc
      bind = ,XF86Calculator, exec, ~/.local/bin/wofi-calc
      # Settings (Super+Comma)
      bind = $Primary$Secondary, comma, exec, quickshell -p ~/.config/quickshell/ii/settings.qml
      # Flux/Gammastep
      bind = $Primary$Secondary, N, exec, gammastep -O +3000 &
      bind = $Primary$Secondary$Alternate, N, exec, gammastep -0 +6500 &

      #+! Window Actions
      bind = $Primary$Secondary, Period, exec, pkill fuzzel || ~/.local/bin/fuzzel-emoji
      bind = $Alternate, F4, killactive,
      bind = $Secondary$Alternate, Space, togglefloating, 
      bind = $Secondary$Alternate, Q, exec, hyprctl kill

      #+! Screenshot & Recording
      bind = $Secondary$Tertiary, 4, exec, grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" - | wl-copy
      bind = $Secondary$Tertiary, 5, exec, ~/.config/quickshell/ii/scripts/record.sh # Record region (no sound)
      bind = $Secondary$Alternate, 5, exec, ~/.config/quickshell/ii/scripts/record --sound
      bind = $Secondary$Tertiary$Alternate, 5, exec, ~/.config/quickshell/ii/scripts/record.sh --fullscreen-sound
      bind = Super+Shift+Alt, mouse:273, exec, ~/.config/quickshell/ii/scripts/ai/primary-buffer-query.sh # AI summary for selected text
      bindl =,Print,exec,grim - | wl-copy
      bind = $Secondary$Alternate, C, exec, hyprpicker -a
      bind = $Primary$Alternate, Space, exec, cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl
      bind = $Secondary$Alternate, V, exec, cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl

      #+! Text Recognition (OCR)
      bind = $Primary$Secondary$Tertiary,S,exec,grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract "tmp.png" - | wl-copy && rm "tmp.png"
      bind = $Secondary$Tertiary,T,exec,grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract -l eng "tmp.png" - | wl-copy && rm "tmp.png"

      # Media controls
      #+! Media Controls
      bind = $Secondary$Tertiary, N, exec, playerctl next || playerctl position `bc <<< "100 * $(playerctl metadata mpris:length) / 1000000 / 100"`
      bindl  = , XF86AudioNext, exec, playerctl next 
      bindl  = , XF86AudioPrev, exec, playerctl previous
      bindl  = , XF86AudioPlay, exec, playerctl play-pause
      bind = $Secondary$Tertiary, B, exec, playerctl previous
      bind = $Secondary$Tertiary, P, exec, playerctl play-pause

      #+! System Actions
      # Lock screen
      bind = $Primary$Secondary, L, exec, hyprlock

      #+! Quickshell Interface
      # Quickshell restart (equivalent to the old AGS restart)
      bindr = $Primary$Secondary, R, exec, pkill quickshell; quickshell -c ii &
      bindr = $Primary$Secondary, T, exec, ~/.config/quickshell/ii/scripts/colors/switchwall.sh
      
      # Desktop environment controls (converted from AGS to Quickshell)
      bind = $Alternate, Tab, exec, hyprctl dispatch global quickshell:overviewToggle
      bind = $Secondary, Space, exec, hyprctl dispatch global quickshell:overviewToggle
      bind = $Secondary, B, exec, hyprctl dispatch global quickshell:sidebarLeftToggle
      bind = $Secondary, N, exec, hyprctl dispatch global quickshell:sidebarRightToggle
      bind = $Secondary, M, exec, hyprctl dispatch global quickshell:mediaControlsToggle
      bind = $Secondary, Comma, exec, hyprctl dispatch global quickshell:settingsToggle
      bind = $Secondary$Alternate, Slash, exec, hyprctl dispatch global quickshell:cheatsheetToggle

      #+! Window Management
      # Swap windows
      bind = $Secondary$Tertiary, left, movewindow, l
      bind = $Secondary$Tertiary, right, movewindow, r
      bind = $Secondary$Tertiary, up, movewindow, u
      bind = $Secondary$Tertiary, down, movewindow, d
      
      # Move focus
      bind = $Secondary, left, movefocus, l
      bind = $Secondary, right, movefocus, r
      bind = $Alternate, up, movefocus, u
      bind = $Alternate, down, movefocus, d
      bind = $Secondary, BracketLeft, movefocus, l
      bind = $Secondary, BracketRight, movefocus, r

      #+! Workspace Navigation
      bind = $Primary$Secondary, right, workspace, +1
      bind = $Primary$Secondary, left, workspace, -1
      bind = $Primary$Secondary, BracketLeft, workspace, -1
      bind = $Primary$Secondary, BracketRight, workspace, +1
      bind = $Primary$Secondary, up, workspace, -5
      bind = $Primary$Secondary, down, workspace, +5
      bind = $Secondary, Page_Down, workspace, +1
      bind = $Secondary, Page_Up, workspace, -1

      # Window split ratio
      binde = $Primary$Secondary, Minus, splitratio, -0.1
      binde = $Primary$Secondary, Equal, splitratio, 0.1
      binde = $Secondary, Semicolon, splitratio, -0.1
      binde = $Secondary, Apostrophe, splitratio, 0.1

      #+! Window States
      # Fullscreen
      bind = $Primary$Secondary, F, fullscreen, 0
      bind = $Primary$Secondary, D, fullscreen, 1
      bind = $Secondary$Alternate, F, fullscreenstate, 0

      #+! Workspace Switching
      bind = $Secondary, 1, workspace, 1
      bind = $Secondary, 2, workspace, 2
      bind = $Secondary, 3, workspace, 3
      bind = $Secondary, 4, workspace, 4
      bind = $Secondary, 5, workspace, 5
      bind = $Secondary, 6, workspace, 6
      bind = $Secondary, 7, workspace, 7
      bind = $Secondary, 8, workspace, 8
      bind = $Secondary, 9, workspace, 9
      bind = $Secondary, 0, workspace, 10
      bind = $Primary$Secondary, S, togglespecialworkspace,
      bind = $Alternate, Tab, cyclenext
      bind = $Alternate, Tab, bringactivetotop,   # bring it to the top

      #+! Move Windows to Workspace
      bind = $Secondary$Alternate, 1, movetoworkspacesilent, 1
      bind = $Secondary$Alternate, 2, movetoworkspacesilent, 2
      bind = $Secondary$Alternate, 3, movetoworkspacesilent, 3
      bind = $Secondary$Alternate, 4, movetoworkspacesilent, 4
      bind = $Secondary$Alternate, 5, movetoworkspacesilent, 5
      bind = $Secondary$Alternate, 6, movetoworkspacesilent, 6
      bind = $Secondary$Alternate, 7, movetoworkspacesilent, 7
      bind = $Secondary$Alternate, 8, movetoworkspacesilent, 8
      bind = $Secondary$Alternate, 9, movetoworkspacesilent, 9
      bind = $Secondary$Alternate, 0, movetoworkspacesilent, 10
      bind = $Secondary$Alternate, S, movetoworkspacesilent, special

      #+! Mouse Controls
      # Mouse workspace scrolling
      bind = $Secondary, mouse_up, workspace, +1
      bind = $Secondary, mouse_down, workspace, -1
      bind = $Primary$Secondary, mouse_up, workspace, +1
      bind = $Primary$Secondary, mouse_down, workspace, -1

      # Mouse window controls
      bindm = $Secondary, mouse:273, resizewindow
      bindm = $Primary$Secondary, mouse:273, resizewindow
      bindm = ,mouse:274, movewindow
      bindm = $Primary$Secondary, Z, movewindow
      bind = $Primary$Secondary, Backslash, resizeactive, exact 640 480

      # Quickshell integration and desktop environment
      exec-once = quickshell -c ii
      exec-once = [workspace name:touch silent] hyte-touch-interface
      exec-once = wl-paste --watch cliphist store
      exec-once = ~/.config/hypr/hyprland/scripts/start_geoclue_agent.sh
      exec-once = gnome-keyring-daemon --start --components=secrets
      exec-once = /usr/lib/polkit-kde-authentication-agent-1 || /usr/libexec/polkit-kde-authentication-agent-1  || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1
      exec-once = hypridle
      exec-once = dbus-update-activation-environment --all
      exec-once = sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP # Some fix idk
      exec-once = hyprpm reload
      exec-once = easyeffects --gapplication-service
    '';
  };  
}
