# Hyprland configuration for nixberry (Parallels Desktop aarch64 VM)
# Simplified: no DP-3 touch display, no HYTE cursor barrier, single monitor.
{ inputs, lib, pkgs, config, ... }:

{
  imports = [
    inputs.ags.homeManagerModules.default
    inputs.dots-hyprland.homeManagerModules.default
  ];

  # dots-hyprland configuration for nixberry
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
      # Hyprland configuration for nixberry (Parallels VM)

      misc {
          disable_hyprland_logo = true
          disable_splash_rendering = true
          force_default_wallpaper = -1
      }

      # Environment variables
      env = XCURSOR_SIZE,24
      env = QT_QPA_PLATFORMTHEME,qt5ct
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
          preserve_split = yes
      }

      master {
          new_status = master
      }

      # Gestures (Hyprland 0.51+ syntax)
      gestures {
          gesture = 3, horizontal, workspace
      }

      # Window rules
      windowrule = suppress_event maximize, match:class .*

      # KEYBIND VARIABLES
      $Primary = Super
      $Secondary = Control
      $Tertiary = Shift
      $Alternate = Alt

      #+! System Controls
      bindl = ,XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle # Toggle mute
      bindle=, XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%+ # Volume up
      bindle=, XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%- # Volume down
      bindle=, XF86MonBrightnessUp, exec, brightnessctl set '12.75+' # Brightness up
      bindle=, XF86MonBrightnessDown, exec, brightnessctl set '12.75-' # Brightness down

      #+! Applications
      bind = $Primary$Secondary, M, exec, tidal-hifi # Tidal HiFi
      bind = $Primary$Secondary, I, exec, discord # Discord
      bind = $Primary$Secondary, G, exec, foot # Terminal (foot)
      bind = $Primary$Secondary$Tertiary, T, exec, foot sleep 0.01 && nmtui # Network manager TUI
      bind = $Primary$Secondary, J, exec, thunar # File manager (Thunar)
      bind = $Primary$Secondary$Tertiary, J, exec, nautilus # File manager (Nautilus)
      bind = $Primary$Secondary, B, exec, firefox # Firefox
      bind = $Primary$Secondary$Tertiary, B, exec, chromium # Chromium
      bind = $Primary$Secondary, U, exec, code # VS Code
      bind = $Primary$Secondary, C, exec, code # VS Code (alt)
      bind = $Primary$Secondary$Tertiary, C, exec, jetbrains-toolbox # JetBrains Toolbox
      bind = $Primary$Secondary, 3, exec, ~/.local/bin/wofi-calc # Calculator
      bind = ,XF86Calculator, exec, ~/.local/bin/wofi-calc # Calculator (media key)

      #+! Window Actions
      bind = $Primary$Secondary, Period, exec, pkill fuzzel || ~/.local/bin/fuzzel-emoji # Emoji picker
      bind = $Alternate, F4, killactive, # Close window
      bind = $Secondary$Alternate, Space, togglefloating, # Toggle floating
      bind = $Secondary$Alternate, Q, exec, hyprctl kill # Force kill window

      #+! Screenshot & Recording
      bind = $Secondary$Tertiary, 4, exec, grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" - | wl-copy # Screen snip >> clipboard
      bind = $Secondary$Tertiary, 5, exec, wf-recorder -g "$(slurp)" # Record region
      bindl =,Print,exec,grim - | wl-copy # Screenshot >> clipboard
      bind = $Secondary$Alternate, C, exec, hyprpicker -a # Color picker >> clipboard
      bind = $Primary$Alternate, Space, exec, cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl # Clipboard history + paste

      #+! Text Recognition (OCR)
      bind = $Primary$Secondary$Tertiary,S,exec,grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract "tmp.png" - | wl-copy && rm "tmp.png" # OCR >> clipboard

      #+! Media Controls
      bind = $Secondary$Tertiary, N, exec, playerctl next # Next track
      bindl  = , XF86AudioNext, exec, playerctl next # Next track (media key)
      bindl  = , XF86AudioPrev, exec, playerctl previous # Previous track (media key)
      bindl  = , XF86AudioPlay, exec, playerctl play-pause # Play/pause (media key)
      bind = $Secondary$Tertiary, B, exec, playerctl previous # Previous track
      bind = $Secondary$Tertiary, P, exec, playerctl play-pause # Play/pause

      #+! System Actions
      bind = $Primary$Secondary, L, exec, hyprlock # Lock screen

      #+! Quickshell Interface
      bindr = $Primary$Secondary, R, exec, systemctl --user reload quickshell.service # Restart Quickshell
      bind = CTRL SUPER, T, exec, ~/.config/quickshell/ii/scripts/colors/switchwall.sh --choose # Choose wallpaper
      bind = CTRL SUPER SHIFT, T, exec, ~/.config/quickshell/ii/scripts/colors/switchwall.sh # Random wallpaper

      # Desktop environment controls
      bind = $Alternate, Tab, exec, hyprctl dispatch global quickshell:overviewToggle # Overview/launcher
      bind = $Secondary, Space, exec, hyprctl dispatch global quickshell:overviewToggle # Overview/launcher (alt)
      bind = $Primary, Space, exec, hyprctl dispatch global quickshell:overviewToggle # [hidden]
      bind = $Secondary, B, exec, hyprctl dispatch global quickshell:sidebarLeftToggle # Left sidebar (AI)
      bind = $Secondary, N, exec, hyprctl dispatch global quickshell:sidebarRightToggle # Right sidebar
      bind = $Secondary, M, exec, hyprctl dispatch global quickshell:mediaControlsToggle # Media controls
      bind = $Secondary, Comma, exec, hyprctl dispatch global quickshell:settingsToggle # Settings panel
      bind = $Secondary$Alternate, Slash, exec, hyprctl dispatch global quickshell:cheatsheetToggle # Cheatsheet

      #+! Window Management
      bind = $Secondary$Tertiary, left, movewindow, l # Move window left
      bind = $Secondary$Tertiary, right, movewindow, r # Move window right
      bind = $Secondary$Tertiary, up, movewindow, u # Move window up
      bind = $Secondary$Tertiary, down, movewindow, d # Move window down
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

      #+! Window States
      bind = $Primary$Secondary, F, fullscreen, 0 # Fullscreen
      bind = $Primary$Secondary, D, fullscreen, 1 # Maximize

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
      bind = $Secondary, mouse_up, workspace, +1 # Scroll workspace next
      bind = $Secondary, mouse_down, workspace, -1 # Scroll workspace prev
      bindm = $Secondary, mouse:273, resizewindow # Resize window (RMB)
      bindm = ,mouse:274, movewindow # Move window (MMB)
      bindm = $Primary$Secondary, Z, movewindow # [hidden]
      bind = $Primary$Secondary, Backslash, resizeactive, exact 640 480 # Resize to 640x480

      # Startup
      exec-once = hyprctl setcursor Bibata-Modern-Classic 24
      exec-once = systemctl --user start quickshell.service
      exec-once = wl-paste --watch cliphist store
      exec-once = gnome-keyring-daemon --start --components=secrets
      exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/libexec/polkit-gnome-authentication-agent-1
      exec-once = hypridle
      exec-once = dbus-update-activation-environment --all
      exec-once = sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

      # Source external custom configuration
      source = ~/.config/hypr/custom.conf
    '';
  };

  # Hyprland monitor/gesture settings
  programs.dots-hyprland.hyprland = {
    general = {
      gapsIn = 4;
      gapsOut = 7;
      borderSize = 2;
      allowTearing = false;
    };
    decoration = {
      rounding = 16;
      blurEnabled = true;
    };
    gestures = {
      workspaceSwipe = true;
    };
    monitors = [ ];  # Let Parallels auto-detect
  };

  # Prevent HM from managing icons dir — Steam needs to write here
  home.file.".local/share/icons".enable = false;
}
