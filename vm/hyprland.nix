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

      # Gestures
      gestures {
          workspace_swipe = true
      }

      # Window rules
      windowrule = suppress_event maximize, match:class .*

      # KEYBIND VARIABLES
      $Primary = Super
      $Secondary = Control
      $Tertiary = Shift
      $Alternate = Alt

      #+! System Controls
      bindl = ,XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle
      bindle=, XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%+
      bindle=, XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-
      bindle=, XF86MonBrightnessUp, exec, brightnessctl set '12.75+'
      bindle=, XF86MonBrightnessDown, exec, brightnessctl set '12.75-'

      #+! Applications
      bind = $Primary$Secondary, M, exec, tidal-hifi
      bind = $Primary$Secondary, I, exec, discord
      bind = $Primary$Secondary, G, exec, foot
      bind = $Primary$Secondary$Tertiary, T, exec, foot sleep 0.01 && nmtui
      bind = $Primary$Secondary, J, exec, thunar
      bind = $Primary$Secondary$Tertiary, J, exec, nautilus
      bind = $Primary$Secondary, B, exec, firefox
      bind = $Primary$Secondary$Tertiary, B, exec, chromium
      bind = $Primary$Secondary, U, exec, code
      bind = $Primary$Secondary, C, exec, code
      bind = $Primary$Secondary$Tertiary, C, exec, jetbrains-toolbox
      bind = $Primary$Secondary, 3, exec, ~/.local/bin/wofi-calc
      bind = ,XF86Calculator, exec, ~/.local/bin/wofi-calc

      #+! Window Actions
      bind = $Primary$Secondary, Period, exec, pkill fuzzel || ~/.local/bin/fuzzel-emoji
      bind = $Alternate, F4, killactive,
      bind = $Secondary$Alternate, Space, togglefloating,
      bind = $Secondary$Alternate, Q, exec, hyprctl kill

      #+! Screenshot & Recording
      bind = $Secondary$Tertiary, 4, exec, grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" - | wl-copy
      bind = $Secondary$Tertiary, 5, exec, wf-recorder -g "$(slurp)"
      bindl =,Print,exec,grim - | wl-copy
      bind = $Secondary$Alternate, C, exec, hyprpicker -a
      bind = $Primary$Alternate, Space, exec, cliphist list | wofi -Iim --dmenu | cliphist decode | wl-copy && wtype -M ctrl v -M ctrl

      #+! Text Recognition (OCR)
      bind = $Primary$Secondary$Tertiary,S,exec,grim -g "$(slurp -d -c D1E5F4BB -b 1B232866 -s 00000000)" "tmp.png" && tesseract "tmp.png" - | wl-copy && rm "tmp.png"

      # Media controls
      bind = $Secondary$Tertiary, N, exec, playerctl next
      bindl  = , XF86AudioNext, exec, playerctl next
      bindl  = , XF86AudioPrev, exec, playerctl previous
      bindl  = , XF86AudioPlay, exec, playerctl play-pause
      bind = $Secondary$Tertiary, B, exec, playerctl previous
      bind = $Secondary$Tertiary, P, exec, playerctl play-pause

      #+! System Actions
      bind = $Primary$Secondary, L, exec, hyprlock

      #+! Quickshell Interface
      bindr = $Primary$Secondary, R, exec, systemctl --user reload quickshell.service
      bind = CTRL SUPER, T, exec, ~/.config/quickshell/ii/scripts/colors/switchwall.sh --choose
      bind = CTRL SUPER SHIFT, T, exec, ~/.config/quickshell/ii/scripts/colors/switchwall.sh

      # Desktop environment controls
      bind = $Alternate, Tab, exec, hyprctl dispatch global quickshell:overviewToggle
      bind = $Secondary, Space, exec, hyprctl dispatch global quickshell:overviewToggle
      bind = $Primary, Space, exec, hyprctl dispatch global quickshell:overviewToggle
      bind = $Secondary, B, exec, hyprctl dispatch global quickshell:sidebarLeftToggle
      bind = $Secondary, N, exec, hyprctl dispatch global quickshell:sidebarRightToggle
      bind = $Secondary, M, exec, hyprctl dispatch global quickshell:mediaControlsToggle
      bind = $Secondary, Comma, exec, hyprctl dispatch global quickshell:settingsToggle
      bind = $Secondary$Alternate, Slash, exec, hyprctl dispatch global quickshell:cheatsheetToggle

      #+! Window Management
      bind = $Secondary$Tertiary, left, movewindow, l
      bind = $Secondary$Tertiary, right, movewindow, r
      bind = $Secondary$Tertiary, up, movewindow, u
      bind = $Secondary$Tertiary, down, movewindow, d
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
      binde = $Primary$Secondary, Minus, layoutmsg, splitratio, -0.1
      binde = $Primary$Secondary, Equal, layoutmsg, splitratio, 0.1

      #+! Window States
      bind = $Primary$Secondary, F, fullscreen, 0
      bind = $Primary$Secondary, D, fullscreen, 1

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
      bind = $Secondary, mouse_up, workspace, +1
      bind = $Secondary, mouse_down, workspace, -1
      bindm = $Secondary, mouse:273, resizewindow
      bindm = ,mouse:274, movewindow
      bindm = $Primary$Secondary, Z, movewindow
      bind = $Primary$Secondary, Backslash, resizeactive, exact 640 480

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
