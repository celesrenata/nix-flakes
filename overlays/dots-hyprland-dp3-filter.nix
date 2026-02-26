# Overlay to filter DP-3 from dots-hyprland quickshell configurations
# This prevents the main desktop quickshell from showing on the Hyte touch display

inputs: final: prev: {
  # Override the dots-hyprland source to filter DP-3 from quickshell modules
  dots-hyprland-source-filtered = prev.runCommand "dots-hyprland-dp3-filtered-v2" {} ''
    mkdir -p $out
    cp -r ${inputs.dots-hyprland-source}/* $out/
    chmod -R +w $out
    
    # Remove matugen from config (managed via staging directory)
    rm -rf $out/.config/matugen
    
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
