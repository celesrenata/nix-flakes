import time, os
import sys
sys.path.insert(0, "/nix/store/cqfswhb3z49anzik87lpan3xm37w0h9x-python3.13-openrgb-python-0.3.6/lib/python3.13/site-packages")

from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

def lerp(c1, c2, t):
    return tuple(int(a + (b-a)*t) for a,b in zip(c1,c2))

scss = os.path.expanduser("~/.local/state/quickshell/user/generated/material_colors.scss")
colors = []
for name in ["primary_paletteKeyColor", "secondary_paletteKeyColor", "tertiary_paletteKeyColor"]:
    with open(scss) as f:
        for line in f:
            if name in line:
                h = line.split("#")[1][:6]
                colors.append((int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)))
                break

print(f"Gradient: {['#%02x%02x%02x' % c for c in colors]}", flush=True)

c = OpenRGBClient()

# Rainbow reset
for d in c.devices:
    for m in d.modes:
        if m.name == "Rainbow":
            d.set_mode(m)
            break
time.sleep(1)
for d in c.devices:
    for m in d.modes:
        if m.name == "Direct":
            d.set_mode(m)
            break

print("Running...", flush=True)
STEPS = 60  # 60 steps per transition, 1s each = 60s per pair, 180s full cycle
DELAY = 1

while True:
    for i in range(len(colors)):
        c1, c2 = colors[i], colors[(i+1) % len(colors)]
        for s in range(STEPS):
            r, g, b = lerp(c1, c2, s / STEPS)
            color = RGBColor(r, g, b)
            for d in c.devices:
                try:
                    d.set_color(color)
                except:
                    pass
            time.sleep(DELAY)
