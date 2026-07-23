# Hyprland window manager configuration
{ inputs, lib, pkgs, config, ... }:

{
  imports = [ 
    inputs.ags.homeManagerModules.default
    inputs.dots-hyprland.homeManagerModules.default
  ];

  # dots-hyprland configuration - HYBRID MODE! 🎯
  programs.dots-hyprland = {
    enable = true;
    source = pkgs.dots-hyprland-source-filtered;  # Use filtered source (no matugen, no DP-3)
    packageSet = "essential";
    mode = "hybrid";  # Hyprland declarative + Quickshell copied (should work now!)
    
    # Enable Python venv for wayland-idle-inhibitor
    python.enable = true;
    
    # Force disable touchegg component (we handle it system-wide)
    touchegg.enable = lib.mkForce false;
    
    # Enable misc config copying to get Quickshell files deployed
    configuration.copyMiscConfig = lib.mkForce true;
    
    # Disable specific conflicting applications
    configuration.applications.foot.enable = lib.mkForce false;
    configuration.applications.kitty.enable = lib.mkForce false;
    configuration.applications.fuzzel.enable = lib.mkForce false;
    
    # Disable fish config copying to prevent read-only fish_variables symlink
    configuration.copyFishConfig = lib.mkForce false;
    
    # COMPLETE OVERRIDE: Provide the entire hyprland.conf with essential keybinds
    overrides.hyprlandConf = ''
      # Complete Hyprland configuration (NixOS-managed, fully declarative)
      # No external file dependencies - everything inline
      
      $qsConfig = ii

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

      # Monitor configuration
      # Conditional based on hostname
      exec-once = [[ "$(hostname)" == "macland" ]] && hyprctl keyword monitor ",1920x1200@60,auto,1" || hyprctl keyword monitor ",preferred,auto,1"
      exec-once = [[ "$(hostname)" == "esnixi" ]] && hyprctl keyword monitor "DP-3,disable"
      
      # T2 MacBook GPU environment variables for proper graphics switching
      env = AQ_DRM_DEVICES,/dev/dri/card1:/dev/dri/card2

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

      # Gestures (Hyprland 0.51+ syntax)
      gestures {
          gesture = 3, horizontal, workspace
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

      #+! Dictation
      bind = Control, H, global, quickshell:dictationTap # Dictation (Logi button)
      bind = , XF86AudioMicMute, global, quickshell:dictationTap # Dictation (mic mute key)
      bind = , F20, global, quickshell:dictationTap # Dictation (Alt tap via keyd)

      #+! System Controls
      # Volume
      bindl = ,XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle # Toggle mute
      bindle=, XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ # Volume up
      bindle=, XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- # Volume down

      # Brightness (updated for Quickshell)
      bindle=, XF86MonBrightnessUp, exec, brightnessctl set '12.75+' && hyprctl dispatch global quickshell:osdShow # Brightness up
      bindle=, XF86MonBrightnessDown, exec, brightnessctl set '12.75-' && hyprctl dispatch global quickshell:osdShow # Brightness down

      #+! Applications
      # Music
      bind = $Primary$Secondary, M, exec, tidal-hifi # Tidal HiFi
      bind = $Primary$Secondary$Tertiary, M, exec, env -u NIXOS_OZONE_WL cider --use-gl=desktop # Cider (Apple Music)
      bind = $Primary$Secondary$Alternate, M, exec, spotify # Spotify
      # Discord
      bind = $Primary$Secondary, I, exec, discord # Discord
      # Foot
      bind = $Primary$Secondary, G, exec, foot # Terminal (foot)
      bind = $Primary$Secondary$Tertiary, T, exec, foot sleep 0.01 && nmtui # Network manager TUI
      # Finders
      bind = $Primary$Secondary, J, exec, thunar # File manager (Thunar)
      bind = $Primary$Secondary$Tertiary, J, exec, nautilus # File manager (Nautilus)
      # Browsers
      bind = $Primary$Secondary, B, exec, firefox # Firefox
      bind = $Primary$Secondary$Tertiary, B, exec, chromium # Chromium
      # Code editors
      bind = $Primary$Secondary, U, exec, code # VS Code
      bind = $Primary$Secondary, X, exec, subl # Sublime Text
      bind = $Primary$Secondary, C, exec, code # VS Code (alt)
      bind = $Primary$Secondary$Tertiary, C, exec, jetbrains-toolbox # JetBrains Toolbox
      # Calculator
      bind = $Primary$Secondary, 3, exec, ~/.local/bin/wofi-calc # Calculator
      bind = ,XF86Calculator, exec, ~/.local/bin/wofi-calc # Calculator (media key)
      # Settings (Super+Comma)
      bind = $Primary$Secondary, comma, exec, quickshell -p ~/.config/quickshell/ii/settings.qml # Settings

      #+! Window Actions
      bind = $Primary$Secondary, Period, exec, pkill fuzzel || ~/.local/bin/fuzzel-emoji # Emoji picker
      bind = $Alternate, F4, killactive, # Close window
      bind = $Secondary$Alternate, Space, togglefloating, # Toggle floating
      bind = $Secondary$Alternate, Q, exec, hyprctl kill # Force kill window

      #+! Screenshot & Recording
      bind = $Secondary$Tertiary, 4, exec, grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" - | wl-copy # Screen snip >> clipboard
      bind = $Secondary$Tertiary, 5, exec, ~/.config/quickshell/ii/scripts/record.sh # Record region (no sound)
      bind = $Secondary$Alternate, 5, exec, ~/.config/quickshell/ii/scripts/record --sound # Record region (with sound)
      bind = $Secondary$Tertiary$Alternate, 5, exec, ~/.config/quickshell/ii/scripts/record.sh --fullscreen-sound # Record fullscreen (with sound)
      bind = Super+Shift+Alt, mouse:273, exec, ~/.config/quickshell/ii/scripts/ai/primary-buffer-query.sh # AI summary for selected text
      bindl =,Print,exec,grim - | wl-copy # Screenshot >> clipboard
      bind = $Secondary$Alternate, C, exec, hyprpicker -a # Color picker >> clipboard
      bind = $Primary$Alternate, Space, exec, cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl # Clipboard history + paste
      bind = $Secondary$Alternate, V, exec, cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl # Clipboard history + paste (alt)

      #+! Text Recognition
      bind = $Primary$Secondary$Tertiary,S,exec,grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract "tmp.png" - | wl-copy && rm "tmp.png" # OCR >> clipboard
      bind = $Secondary$Tertiary,T,exec,grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract -l eng "tmp.png" - | wl-copy && rm "tmp.png" # OCR English >> clipboard

      # Media controls
      #+! Media Controls
      bind = $Secondary$Tertiary, N, exec, playerctl next || playerctl position `bc <<< "100 * $(playerctl metadata mpris:length) / 1000000 / 100"` # Next track
      bindl  = , XF86AudioNext, exec, playerctl next # Next track (media key)
      bindl  = , XF86AudioPrev, exec, playerctl previous # Previous track (media key)
      bindl  = , XF86AudioPlay, exec, playerctl play-pause # Play/pause (media key)
      bind = $Secondary$Tertiary, B, exec, playerctl previous # Previous track
      bind = $Secondary$Tertiary, P, exec, playerctl play-pause # Play/pause

      #+! System Actions
      # Lock screen
      bind = $Primary$Secondary, L, exec, hyprlock # Lock screen

      #+! Quickshell Interface
      # Quickshell restart (equivalent to the old AGS restart)
      bindr = $Primary$Secondary, R, exec, pkill quickshell; quickshell -c ii & # Restart Quickshell
      bindr = $Primary$Secondary, T, exec, ~/.config/quickshell/ii/scripts/colors/switchwall.sh # Change wallpaper
      
      # Desktop environment controls (converted from AGS to Quickshell)
      bind = $Alternate, Tab, exec, hyprctl dispatch global quickshell:overviewToggle # Overview/launcher
      bind = $Secondary, Space, exec, hyprctl dispatch global quickshell:overviewToggle # Overview/launcher (alt)
      bind = $Secondary, B, exec, hyprctl dispatch global quickshell:sidebarLeftToggle # Left sidebar
      bind = $Secondary, N, exec, hyprctl dispatch global quickshell:sidebarRightToggle # Right sidebar
      bind = $Secondary, M, exec, hyprctl dispatch global quickshell:mediaControlsToggle # Media controls
      bind = $Secondary, Comma, exec, hyprctl dispatch global quickshell:settingsToggle # Settings panel
      bind = $Secondary$Alternate, Slash, exec, hyprctl dispatch global quickshell:cheatsheetToggle # Cheatsheet

      #+! Window Management
      # Swap windows
      bind = $Secondary$Tertiary, left, movewindow, l # Move window left
      bind = $Secondary$Tertiary, right, movewindow, r # Move window right
      bind = $Secondary$Tertiary, up, movewindow, u # Move window up
      bind = $Secondary$Tertiary, down, movewindow, d # Move window down
      
      # Move focus
      bind = $Secondary, left, movefocus, l # Focus left
      bind = $Secondary, right, movefocus, r # Focus right
      bind = $Alternate, up, movefocus, u # Focus up
      bind = $Alternate, down, movefocus, d # Focus down
      bind = $Secondary, BracketLeft, movefocus, l # Focus left (bracket)
      bind = $Secondary, BracketRight, movefocus, r # Focus right (bracket)

      #+! Workspace Navigation
      bind = $Primary$Secondary, right, workspace, +1 # Next workspace
      bind = $Primary$Secondary, left, workspace, -1 # Previous workspace
      bind = $Primary$Secondary, BracketLeft, workspace, -1 # Previous workspace (bracket)
      bind = $Primary$Secondary, BracketRight, workspace, +1 # Next workspace (bracket)
      bind = $Primary$Secondary, up, workspace, -5 # Jump 5 workspaces back
      bind = $Primary$Secondary, down, workspace, +5 # Jump 5 workspaces forward
      bind = $Secondary, Page_Down, workspace, +1 # Next workspace (PgDn)
      bind = $Secondary, Page_Up, workspace, -1 # Previous workspace (PgUp)

      # Window split ratio
      binde = $Primary$Secondary, Minus, layoutmsg, splitratio, -0.1 # Shrink split
      binde = $Primary$Secondary, Equal, layoutmsg, splitratio, 0.1 # Grow split
      binde = $Secondary, Semicolon, layoutmsg, splitratio, -0.1 # Shrink split (alt)
      binde = $Secondary, Apostrophe, layoutmsg, splitratio, 0.1 # Grow split (alt)

      #+! Window States
      # Fullscreen
      bind = $Primary$Secondary, F, fullscreen, 0 # Fullscreen
      bind = $Primary$Secondary, D, fullscreen, 1 # Maximize
      bind = $Secondary$Alternate, F, fullscreenstate, 0 # Fullscreen spoof

      #+! Workspace Switching
      bind = $Secondary, 1, workspace, 1 # Workspace 1
      bind = $Secondary, 2, workspace, 2 # Workspace 2
      bind = $Secondary, 3, workspace, 3 # Workspace 3
      bind = $Secondary, 4, workspace, 4 # Workspace 4
      bind = $Secondary, 5, workspace, 5 # Workspace 5
      bind = $Secondary, 6, workspace, 6 # Workspace 6
      bind = $Secondary, 7, workspace, 7 # Workspace 7
      bind = $Secondary, 8, workspace, 8 # Workspace 8
      bind = $Secondary, 9, workspace, 9 # Workspace 9
      bind = $Secondary, 0, workspace, 10 # Workspace 10
      bind = $Primary$Secondary, S, togglespecialworkspace, # Scratchpad
      bind = $Alternate, Tab, cyclenext # Cycle windows
      bind = $Alternate, Tab, bringactivetotop, # [hidden]

      #+! Move Windows to Workspace
      bind = $Secondary$Alternate, 1, movetoworkspacesilent, 1 # Send to workspace 1
      bind = $Secondary$Alternate, 2, movetoworkspacesilent, 2 # Send to workspace 2
      bind = $Secondary$Alternate, 3, movetoworkspacesilent, 3 # Send to workspace 3
      bind = $Secondary$Alternate, 4, movetoworkspacesilent, 4 # Send to workspace 4
      bind = $Secondary$Alternate, 5, movetoworkspacesilent, 5 # Send to workspace 5
      bind = $Secondary$Alternate, 6, movetoworkspacesilent, 6 # Send to workspace 6
      bind = $Secondary$Alternate, 7, movetoworkspacesilent, 7 # Send to workspace 7
      bind = $Secondary$Alternate, 8, movetoworkspacesilent, 8 # Send to workspace 8
      bind = $Secondary$Alternate, 9, movetoworkspacesilent, 9 # Send to workspace 9
      bind = $Secondary$Alternate, 0, movetoworkspacesilent, 10 # Send to workspace 10
      bind = $Secondary$Alternate, S, movetoworkspacesilent, special # Send to scratchpad

      #+! Mouse Controls
      # Mouse workspace scrolling
      bind = $Secondary, mouse_up, workspace, +1 # Scroll workspace next
      bind = $Secondary, mouse_down, workspace, -1 # Scroll workspace prev
      bind = $Primary$Secondary, mouse_up, workspace, +1 # [hidden]
      bind = $Primary$Secondary, mouse_down, workspace, -1 # [hidden]

      # Mouse window controls
      bindm = $Secondary, mouse:273, resizewindow # Resize window (RMB)
      bindm = $Primary$Secondary, mouse:273, resizewindow # [hidden]
      bindm = ,mouse:274, movewindow # Move window (MMB)
      bindm = $Primary$Secondary, Z, movewindow # [hidden]
      bind = $Primary$Secondary, Backslash, resizeactive, exact 640 480 # Resize to 640x480

      # Quickshell integration and desktop environment
      exec-once = quickshell -c ii
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

  # MacBook T2 specific GPU card configuration files
  home.file.".config/hypr/card-intel".text = "/dev/dri/card1";
  home.file.".config/hypr/card-amd".text = "/dev/dri/card2";
}
