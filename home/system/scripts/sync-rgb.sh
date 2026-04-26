#!/usr/bin/env bash
# Sync OpenRGB to material-you wallpaper colors
SCSS="$HOME/.local/state/quickshell/user/generated/material_colors.scss"

if [ ! -f "$SCSS" ] || [ ! -s "$SCSS" ]; then
    echo "No material colors found"
    exit 1
fi

PRIMARY=$(grep "primary_paletteKeyColor" "$SCSS" | grep -oP '#\K[A-Fa-f0-9]{6}' | head -1)
if [ -z "$PRIMARY" ]; then
    echo "Could not extract primary color"
    exit 1
fi

R=$((16#${PRIMARY:0:2}))
G=$((16#${PRIMARY:2:2}))
B=$((16#${PRIMARY:4:2}))

echo "Syncing RGB to #$PRIMARY"

nix-shell -p python313Packages.openrgb-python --run "python3 -c \"
import time
from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

c = OpenRGBClient()
color = RGBColor($R, $G, $B)

# Rainbow reset to unstick controllers
for d in c.devices:
    for m in d.modes:
        if m.name == 'Rainbow':
            d.set_mode(m)
            break
time.sleep(1)

# Apply wallpaper color
for d in c.devices:
    for m in d.modes:
        if m.name == 'Direct':
            d.set_mode(m)
            break
    d.set_color(color)
print('Set all to #$PRIMARY')
\"" 2>/dev/null

echo "RGB synced to #$PRIMARY"
