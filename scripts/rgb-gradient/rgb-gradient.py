import time, os, json
from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

def lerp(c1, c2, t):
    return tuple(int(a + (b-a)*t) for a,b in zip(c1,c2))

def hex_to_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16))

def led_correct(rgb):
    """Gamma correction with selective green suppression for ARGB LED strips."""
    gamma = 2.8
    r, g, b = [int(255 * (c / 255) ** gamma) for c in rgb]
    # Only suppress green when blue dominates (purple/blue hues)
    # This prevents greens from turning to mud
    if b > g:
        g = int(g * 0.5)
    return (r, g, b)

COLORS_JSON = os.path.expanduser("~/.local/state/quickshell/user/generated/colors.json")

def load_colors():
    with open(COLORS_JSON) as f:
        palette = json.load(f)
    colors = [
        led_correct(hex_to_rgb(palette["primary"])),
        led_correct(hex_to_rgb(palette["secondary"])),
        led_correct(hex_to_rgb(palette["tertiary"])),
    ]
    print(f"Gradient: {['#%02x%02x%02x' % c for c in colors]}", flush=True)
    return colors

def get_mtime():
    try:
        return os.path.getmtime(COLORS_JSON)
    except OSError:
        return 0

STEPS = 60
DELAY = 1

def run_client():
    # OpenRGB 1.0 advertises protocol 4 but does not answer the plugin-list
    # request made by openrgb-python. Protocol 3 supports all device/color
    # operations we use and avoids that incompatible request.
    client = OpenRGBClient(name="wallpaper-gradient", protocol_version=3)
    colors = load_colors()
    last_mtime = get_mtime()

    for device in client.devices:
        direct = next((mode for mode in device.modes if mode.name == "Direct"), None)
        if direct is not None:
            device.set_mode(direct)

    print(f"Running on {len(client.devices)} OpenRGB devices", flush=True)
    while True:
        for i in range(len(colors)):
            c1, c2 = colors[i], colors[(i + 1) % len(colors)]
            for step in range(STEPS):
                mtime = get_mtime()
                if mtime != last_mtime:
                    last_mtime = mtime
                    colors = load_colors()
                    break
                color = RGBColor(*lerp(c1, c2, step / STEPS))
                for device in client.devices:
                    device.set_color(color)
                time.sleep(DELAY)

while True:
    try:
        run_client()
    except Exception as error:
        print(f"OpenRGB disconnected ({error!r}); reconnecting in 5s", flush=True)
        time.sleep(5)
