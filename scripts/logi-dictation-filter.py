#!/usr/bin/env python3
"""
Logitech Dictation Button Filter

Grabs keyd's virtual keyboard, intercepts the firmware macro sequence:
  Control_L down/up → MicMute down/up → Control_L down/up
and replaces it with a single F20 press/release.

ALL other events are forwarded immediately and unchanged.
The virtual output device copies ALL capabilities from the source device
so Hyprland/libinput recognizes it as a full keyboard.
"""

import asyncio
import sys
import os
import glob
from evdev import InputDevice, UInput, ecodes, InputEvent

# Sequence timeout — Logi firmware macro completes in ~7ms
SEQUENCE_TIMEOUT = 0.08

# Post-keyd sequence: Control_L tap → MicMute → Control_L tap
CTRL_KEY = ecodes.KEY_LEFTCTRL
MICMUTE_KEY = 248  # KEY_MICMUTE
OUTPUT_KEY = ecodes.KEY_F20

# States
IDLE = 0
GOT_CTRL_DOWN = 1
GOT_CTRL_UP = 2
GOT_MICMUTE_DOWN = 3
GOT_MICMUTE_UP = 4
GOT_CTRL2_DOWN = 5


def find_keyd_virtual_keyboard():
    """Find keyd's virtual keyboard device by name."""
    for path in sorted(glob.glob("/dev/input/event*")):
        try:
            dev = InputDevice(path)
            if dev.name == "keyd virtual keyboard":
                dev.close()
                return path
        except (PermissionError, OSError):
            continue
    return None


class DictationFilter:
    def __init__(self, device_path):
        self.device = InputDevice(device_path)
        
        # Create virtual device with SAME capabilities as source
        # This ensures Hyprland/libinput treats it as a real keyboard
        self.uinput = UInput.from_device(self.device,
                                         name="keyd virtual keyboard (filtered)")
        
        self.state = IDLE
        self.buffer = []
        self.timeout_handle = None
        self.loop = None

    def grab(self):
        self.device.grab()

    def forward(self, ev):
        """Forward a single event to the virtual device."""
        self.uinput.write_event(ev)
        # Don't call syn() here — forward SYN events from source naturally

    def flush_buffer(self):
        """Replay all buffered events."""
        for ev in self.buffer:
            self.forward(ev)
        self.buffer = []
        self.state = IDLE

    def emit_f20(self):
        """Emit a single F20 press/release with SYN."""
        self.uinput.write(ecodes.EV_KEY, OUTPUT_KEY, 1)
        self.uinput.write(ecodes.EV_SYN, ecodes.SYN_REPORT, 0)
        self.uinput.write(ecodes.EV_KEY, OUTPUT_KEY, 0)
        self.uinput.write(ecodes.EV_SYN, ecodes.SYN_REPORT, 0)
        self.buffer = []
        self.state = IDLE

    def cancel_timeout(self):
        if self.timeout_handle is not None:
            self.timeout_handle.cancel()
            self.timeout_handle = None

    def start_timeout(self):
        self.cancel_timeout()
        self.timeout_handle = self.loop.call_later(SEQUENCE_TIMEOUT, self._on_timeout)

    def _on_timeout(self):
        """Sequence didn't complete — flush buffer as normal events."""
        self.timeout_handle = None
        self.flush_buffer()

    def process_event(self, ev):
        """Process an input event. Only EV_KEY is examined for the sequence."""
        # Non-key events: forward immediately if idle, buffer if mid-sequence
        if ev.type != ecodes.EV_KEY:
            if self.state == IDLE:
                self.forward(ev)
            else:
                self.buffer.append(ev)
            return

        key = ev.code
        value = ev.value  # 0=up, 1=down, 2=repeat

        if self.state == IDLE:
            if key == CTRL_KEY and value == 1:
                self.buffer.append(ev)
                self.state = GOT_CTRL_DOWN
                self.start_timeout()
            else:
                self.forward(ev)

        elif self.state == GOT_CTRL_DOWN:
            if key == CTRL_KEY and value == 0:
                self.buffer.append(ev)
                self.state = GOT_CTRL_UP
            else:
                self.cancel_timeout()
                self.buffer.append(ev)
                self.flush_buffer()

        elif self.state == GOT_CTRL_UP:
            if key == MICMUTE_KEY and value == 1:
                self.buffer.append(ev)
                self.state = GOT_MICMUTE_DOWN
            else:
                self.cancel_timeout()
                self.buffer.append(ev)
                self.flush_buffer()

        elif self.state == GOT_MICMUTE_DOWN:
            if key == MICMUTE_KEY and value == 0:
                self.buffer.append(ev)
                self.state = GOT_MICMUTE_UP
            else:
                self.cancel_timeout()
                self.buffer.append(ev)
                self.flush_buffer()

        elif self.state == GOT_MICMUTE_UP:
            if key == CTRL_KEY and value == 1:
                self.buffer.append(ev)
                self.state = GOT_CTRL2_DOWN
            else:
                self.cancel_timeout()
                self.buffer.append(ev)
                self.flush_buffer()

        elif self.state == GOT_CTRL2_DOWN:
            if key == CTRL_KEY and value == 0:
                # SEQUENCE COMPLETE — emit F20
                self.cancel_timeout()
                self.emit_f20()
            else:
                self.cancel_timeout()
                self.buffer.append(ev)
                self.flush_buffer()

    async def run(self):
        """Main loop."""
        self.loop = asyncio.get_event_loop()
        
        # Create virtual device FIRST, then wait for Hyprland to discover it
        print(f"Created virtual device: {self.uinput.device.path}", flush=True)
        print("Waiting 2s for Hyprland to discover new device...", flush=True)
        await asyncio.sleep(2)
        
        # NOW grab the source — Hyprland should have the new device ready
        self.grab()
        print(f"Filter active: {self.device.path} -> {self.uinput.device.path}",
              flush=True)

        async for ev in self.device.async_read_loop():
            self.process_event(ev)


def main():
    device_path = find_keyd_virtual_keyboard()
    if not device_path:
        print("Error: 'keyd virtual keyboard' not found", file=sys.stderr)
        sys.exit(1)

    print(f"Found keyd virtual keyboard: {device_path}", flush=True)

    filt = DictationFilter(device_path)
    try:
        asyncio.run(filt.run())
    except KeyboardInterrupt:
        pass
    finally:
        try:
            filt.device.ungrab()
        except Exception:
            pass


if __name__ == "__main__":
    main()
