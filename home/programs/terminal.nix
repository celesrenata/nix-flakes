# Terminal emulators and terminal-related programs
{ inputs, lib, pkgs, pkgs-unstable, ... }:

{
  # Alacritty terminal emulator
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";
      font = {
        size = 12;
        draw_bold_text_with_bright_colors = true;
      };
      scrolling.multiplier = 5;
      selection.save_to_clipboard = true;
    };
  };

  # Terminal packages
  home.packages = with pkgs; [
    # Terminal emulators
    foot
    kitty
    
    # Terminal utilities
    starship  # customizable prompt
    
    # Wayland terminal tools
    ydotool   # input automation for Wayland
    wtype     # text input for Wayland
    wl-clipboard  # clipboard utilities for Wayland
    
    # Terminal multiplexers and session management
    # (add tmux, screen, etc. if needed)
  ];

  # 🖥️ Terminal Configuration (commented out for hybrid mode testing)
  # This would be used if we had a custom terminal configuration module
  # terminal = {
  #   scrollback = {
  #     lines = 1000;
  #     multiplier = 3.0;
  #   };
  #   
  #   cursor = {
  #     style = "beam";
  #     blink = false;
  #     beamThickness = 1.5;
  #   };
  #   
  #   colors = {
  #     alpha = 0.95;
  #   };
  #   
  #   mouse = {
  #     hideWhenTyping = false;
  #     alternateScrollMode = true;
  #   };
  # };
}
