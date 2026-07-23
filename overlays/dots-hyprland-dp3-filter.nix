# Overlay to filter DP-3 from dots-hyprland quickshell configurations
# This prevents the main desktop quickshell from showing on the Hyte touch display
# Sources from end-4-flakes (dots-hyprland input) which has all our custom Quickshell config

inputs: final: prev: {
  dots-hyprland-source-filtered = prev.runCommand "dots-hyprland-dp3-filtered-v2" {} ''
    mkdir -p $out
    cp -r ${inputs.dots-hyprland}/. $out/
    chmod -R +w $out
    
    # Restructure: end-4-flakes uses configs/ layout, dots-hyprland module expects .config/
    if [ -d "$out/configs/quickshell" ] && [ ! -d "$out/.config/quickshell" ]; then
      mkdir -p $out/.config
      cp -r $out/configs/quickshell $out/.config/quickshell
    fi
    if [ -d "$out/configs/hypr" ] && [ ! -d "$out/.config/hypr" ]; then
      mkdir -p $out/.config/hypr
      cp -r $out/configs/hypr/* $out/.config/hypr/
    fi

    # Remove matugen from config (managed via staging directory)
    rm -rf $out/.config/matugen

    # Remove .local/share/icons so it becomes a real directory (Steam needs to write here)
    rm -rf $out/.local/share/icons
    
    # Filter DP-3 from all quickshell modules that use Quickshell.screens
    find $out -name "*.qml" -type f | while read file; do
      # Handle simple model assignments
      if grep -q "model: Quickshell\.screens$" "$file"; then
        sed -i 's/model: Quickshell\.screens$/model: Quickshell.screens.filter(screen => screen.name !== "DP-3")/g' "$file"
      fi
      
      # Handle const screens assignments  
      if grep -q "const screens = Quickshell\.screens;" "$file"; then
        sed -i 's/const screens = Quickshell\.screens;/const screens = Quickshell.screens.filter(screen => screen.name !== "DP-3");/g' "$file"
      fi
      
      # Handle brightness service screen mapping
      if grep -q "Quickshell\.screens\.map" "$file"; then
        sed -i 's/Quickshell\.screens\.map/Quickshell.screens.filter(screen => screen.name !== "DP-3").map/g' "$file"
      fi
    done
  '';
}
