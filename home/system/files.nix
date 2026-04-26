# Home directory file management and dotfiles
{ inputs, lib, pkgs, ... }:

let
  celes-dots = pkgs.fetchFromGitHub {
    owner = "celesrenata";
    repo = "dotfiles";
    rev = "84ffef9c6f9c0fb204cf7e3561d6dd05434b115c";
    sha256 = "sha256-RwK8A7kBCrNlU+Y7Nfc0P0jK8WO6d3fo49T65CZo+F8=";
  };
  
  wofi-calc = pkgs.fetchFromGitHub {
    owner = "Zeioth";
    repo = "wofi-calc";
    rev = "edd316f3f40a6fcb2afadf5b6d9b14cc75a901e0";
    sha256 = "sha256-y8GoTHm0zPkeXhYS/enNAIrU+RhrUMnQ41MdHWWTPas=";
  };
  
  winapps = pkgs.fetchFromGitHub {
    owner = "celesrenata";
    repo = "winapps";
    rev = "0319c70fa0dec2da241e9a4b4e35a164f99d6307";
    sha256 = "sha256-+ZAtEDrHuLJBzF+R6guD7jYltoQcs88qEMvvpjiAXqI=";
  };
in
{
  # Dotfiles and configuration files
  home.file."Pictures/Wallpapers" = {
    source = celes-dots + "/Backgrounds";
    recursive = true;
  }; 
  
  # Winapps configuration
  home.file."winapps/pkg" = {
    source = winapps;
    recursive = true;
    executable = true;
  };
  
  home.file."winapps/runmefirst.sh" = {
    source = winapps + "/runmefirst.sh";
  };
  
  # ── Systemd oneshot: initial wallpaper/colorgen (needs Hyprland) ─────
  systemd.user.services.dots-initial-colorgen = {
    Unit = {
      Description = "Initial wallpaper and color scheme generation";
      After = [ "graphical-session.target" ];
      ConditionPathExists = "!%h/.local/share/initialSetup";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = [
        "PATH=/etc/profiles/per-user/celes/bin:/run/current-system/sw/bin"
        "LD_LIBRARY_PATH="
      ];
      ExecStart = toString (pkgs.writeShellScript "dots-initial-colorgen" ''
        sleep 3  # let Hyprland settle
        imgpath="$(readlink -f "$HOME/Pictures/Wallpapers/love-is-love.jpg")"
        if [ -f "$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh" ]; then
          "$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh" "$imgpath"
        fi
        touch "$HOME/.local/share/initialSetup"
      '');
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Staging directory for mutable configs (used by dotsSetup activation)
  home.file.".configstaging/quickshell" = {
    source = inputs.dots-hyprland-source + "/.config/quickshell";
    recursive = true;
  };
  
  home.file.".configstaging/matugen" = {
    source = inputs.dots-hyprland-source + "/.config/matugen";
    recursive = true;
  };
  
  home.file.".configstaging/hypr/hyprland" = {
    source = inputs.dots-hyprland-source + "/.config/hypr/hyprland";
    recursive = true;
  };

  # Local bin scripts
  # ── Home activation: replaces initialSetup.sh ──────────────────────────
  home.activation.dotsSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Icons: ensure real directory (Steam writes here)
    if [ -L "$HOME/.local/share/icons" ]; then
      rm "$HOME/.local/share/icons"
    fi
    mkdir -p "$HOME/.local/share/icons"
    cp -n ${inputs.dots-hyprland-source}/.local/share/icons/* "$HOME/.local/share/icons/" 2>/dev/null || true

    # Create mutable config directories
    mkdir -p "$HOME/.config/foot"
    mkdir -p "$HOME/.config/fuzzel"
    mkdir -p "$HOME/.config/gtk-4.0"
    mkdir -p "$HOME/.config/hypr/custom/scripts"
    mkdir -p "$HOME/.local/state/quickshell/user/generated"/{foot,terminal,fuzzel,wallpaper}
    mkdir -p "$HOME/Videos"

    # Remove stale matugen symlink (managed via staging)
    if [ -L "$HOME/.config/matugen" ]; then
      rm "$HOME/.config/matugen"
    fi

    # Sync staging configs → mutable config (--update = don't clobber user edits)
    chmod -R u+w "$HOME/.config/" "$HOME/.local/state/quickshell/" 2>/dev/null || true
    ${pkgs.rsync}/bin/rsync -azL --update --no-perms "$HOME/.configstaging/" "$HOME/.config" 2>/dev/null || true
    chmod -R u+w "$HOME/.local/state/quickshell/user/generated/" \
      "$HOME/.config/fuzzel/" "$HOME/.config/foot/" "$HOME/.config/gtk-4.0/" \
      "$HOME/.config/hypr/hyprland/" "$HOME/.config/matugen/" 2>/dev/null || true

    # Default custom.conf if missing
    if [ ! -f "$HOME/.config/hypr/custom.conf" ]; then
      echo "monitor=,preferred,auto,1" > "$HOME/.config/hypr/custom.conf"
    fi

    # Sync system touchegg config to user config
    mkdir -p "$HOME/.config/touchegg"
    cp /etc/touchegg/touchegg.conf "$HOME/.config/touchegg/touchegg.conf" 2>/dev/null || true
  '';
  
  home.file.".local/bin/apply-idle-config.sh" = {
    executable = true;
    source = ./scripts/apply-idle-config.sh;
  };

  home.file.".local/bin/sync-rgb.sh" = {
    executable = true;
    source = ./scripts/sync-rgb.sh;
  };

  home.file.".local/bin/sunshine" = {
    source = celes-dots + "/.local/bin/sunshineFixed";
  };
  
  home.file.".local/bin/agsAction.sh" = {
    source = celes-dots + "/.local/bin/agsAction.sh";
  };
  
  home.file.".local/bin/regexEscape.sh" = {
    source = celes-dots + "/.local/bin/regexEscape.sh";
  };
  
  home.file.".local/bin/wofi-calc" = {
    source = wofi-calc + "/wofi-calc.sh";
  };
  
  # Fish auto-completion scripts (manual copy to avoid fish_variables conflicts)
  home.file.".config/fish/auto-Hypr.fish" = {
    source = "${inputs.dots-hyprland-source}/.config/fish/auto-Hypr.fish";
  };

  # Commented out Toshy-related files (replaced by keyd)
  # These are kept as comments for reference in case you want to re-enable Toshy
  
  # home.file.".configstaging/toshy/toshy_config.py" = {
  #   source = "${pkgs.toshy}/toshy_config.py";
  # };
  # home.file.".configstaging/toshy/toshy_user_preferences.sqlite" = {
  #   source = "${pkgs.toshy}/toshy_user_preferences.sqlite";
  # };
  
  # Multiple Toshy bin scripts would go here...
  # (commented out for brevity - they're all in the original file)
}
