import time, os, json
from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

def lerp(c1, c2, t):
    return tuple(int(a + (b-a)*t) for a,b in zip(c1,c2))

def hex_to_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16))

def led_correct(rgb):
    """Gamma + green suppression for ARGB LED strips."""
    gamma = 2.8
    r, g, b = [int(255 * (c / 255) ** gamma) for c in rgb]
    g = int(g * 0.5)
    return (r, g, b)

colors_json = os.path.expanduser("~/.local/state/quickshell/user/generated/colors.json")
with open(colors_json) as f:
    palette = json.load(f)

colors = [
    led_correct(hex_to_rgb(palette["primary"])),
    led_correct(hex_to_rgb(palette["secondary"])),
    led_correct(hex_to_rgb(palette["tertiary"])),
]

print(f"Gradient: {['#%02x%02x%02x' % c for c in colors]}", flush=True)

c = OpenRGBClient()

# Rainbow reset to clear hardware state
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
STEPS = 60
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
