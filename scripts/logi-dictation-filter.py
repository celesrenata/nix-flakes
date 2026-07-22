#!/usr/bin/env python3
"""
Logitech Dictation Button Filter

Grabs the Logitech USB Receiver keyboard (event0) and consumer control (event2)
device nodes, intercepts the firmware macro sequence:
  Meta_L down/up → MicMute down/up → Meta_L down/up
and replaces it with a single F20 press/release.

All other events are forwarded unchanged with minimal latency.
"""

import asyncio
import sys
import os
from evdev import InputDevice, UInput, ecodes, InputEvent, categorize

# Sequence timeout in seconds — Logi firmware macro is very fast (~5ms between events)
SEQUENCE_TIMEOUT = 0.10  # 100ms is generous

# The post-keyd sequence (after Meta→Control swap):
# KEY_LEFTCTRL down → KEY_LEFTCTRL up → KEY_MICMUTE down → KEY_MICMUTE up → KEY_LEFTCTRL down → KEY_LEFTCTRL up
META_KEY = ecodes.KEY_LEFTCTRL  # After keyd swap, physical Meta becomes Control
MICMUTE_KEY = 248  # KEY_MICMUTE
OUTPUT_KEY = ecodes.KEY_F20

# State machine states
IDLE = 0
GOT_META_DOWN = 1
GOT_META_UP = 2
GOT_MICMUTE_DOWN = 3
GOT_MICMUTE_UP = 4
GOT_META2_DOWN = 5


class DictationFilter:
    def __init__(self, device_path):
        self.device = InputDevice(device_path)
        
        # Create virtual device that can emit all keys
        self.uinput = UInput(name="Logitech Dictation Filtered",
                           events={ecodes.EV_KEY: list(range(0, 768))})
        
        self.state = IDLE
        self.buffer = []
        self.timeout_task = None
        
    def grab_devices(self):
        """Grab the device so raw events don't reach other consumers."""
        self.device.grab()
        
    def flush_buffer(self):
        """Replay all buffered events through the virtual device."""
        for ev in self.buffer:
            self.uinput.write_event(ev)
            self.uinput.syn()
        self.buffer = []
        self.state = IDLE
        
    def emit_f20(self):
        """Emit a single F20 press/release."""
        self.uinput.write(ecodes.EV_KEY, OUTPUT_KEY, 1)
        self.uinput.syn()
        self.uinput.write(ecodes.EV_KEY, OUTPUT_KEY, 0)
        self.uinput.syn()
        self.buffer = []
        self.state = IDLE
        
    def cancel_timeout(self):
        if self.timeout_task and not self.timeout_task.done():
            self.timeout_task.cancel()
            self.timeout_task = None
            
    def start_timeout(self):
        self.cancel_timeout()
        self.timeout_task = asyncio.ensure_future(self._timeout())
        
    async def _timeout(self):
        await asyncio.sleep(SEQUENCE_TIMEOUT)
        # Sequence didn't complete in time — flush buffer
        self.flush_buffer()
        
    def process_event(self, ev):
        """Process a single input event through the state machine."""
        # Only care about EV_KEY events for sequence detection
        if ev.type != ecodes.EV_KEY:
            if self.state == IDLE:
                self.uinput.write_event(ev)
                self.uinput.syn()
            else:
                self.buffer.append(ev)
            return
            
        key = ev.code
        value = ev.value  # 0=up, 1=down, 2=repeat
        
        if self.state == IDLE:
            if key == META_KEY and value == 1:
                self.buffer.append(ev)
                self.state = GOT_META_DOWN
                self.start_timeout()
            else:
                self.uinput.write_event(ev)
                self.uinput.syn()
                
        elif self.state == GOT_META_DOWN:
            if key == META_KEY and value == 0:
                self.buffer.append(ev)
                self.state = GOT_META_UP
            else:
                # Not our sequence — flush and forward
                self.cancel_timeout()
                self.buffer.append(ev)
                self.flush_buffer()
                
        elif self.state == GOT_META_UP:
            if key == MICMUTE_KEY and value == 1:
                self.buffer.append(ev)
                self.state = GOT_MICMUTE_DOWN
            else:
                # Not our sequence
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
            if key == META_KEY and value == 1:
                self.buffer.append(ev)
                self.state = GOT_META2_DOWN
            else:
                self.cancel_timeout()
                self.buffer.append(ev)
                self.flush_buffer()
                
        elif self.state == GOT_META2_DOWN:
            if key == META_KEY and value == 0:
                # SEQUENCE COMPLETE — swallow everything, emit F20
                self.cancel_timeout()
                self.emit_f20()
            else:
                self.cancel_timeout()
                self.buffer.append(ev)
                self.flush_buffer()

    async def run(self):
        """Main event loop — read from the device."""
        self.grab_devices()
        print(f"Grabbed keyd virtual keyboard, filter active. Virtual device: {self.uinput.device.path}", 
              flush=True)
        
        async for ev in self.device.async_read_loop():
            self.process_event(ev)


def find_keyd_virtual_keyboard():
    """Find keyd's virtual keyboard device by name."""
    import glob
    for path in sorted(glob.glob("/dev/input/event*")):
        try:
            dev = InputDevice(path)
            if dev.name == "keyd virtual keyboard":
                return path
        except (PermissionError, OSError):
            continue
    return None


def main():
    device_path = find_keyd_virtual_keyboard()
    if not device_path:
        print("Error: could not find 'keyd virtual keyboard' device", file=sys.stderr)
        sys.exit(1)
    
    print(f"Found keyd virtual keyboard at {device_path}", flush=True)
    
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
