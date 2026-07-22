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

# The raw sequence the Logi Dictation button sends (before keyd):
# KEY_LEFTMETA down → KEY_LEFTMETA up → KEY_MICMUTE down → KEY_MICMUTE up → KEY_LEFTMETA down → KEY_LEFTMETA up
META_KEY = ecodes.KEY_LEFTMETA
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
    def __init__(self, kbd_path, consumer_path):
        self.kbd_dev = InputDevice(kbd_path)
        self.consumer_dev = InputDevice(consumer_path)
        
        # Create virtual device that can emit all keys
        self.uinput = UInput(name="Logitech Dictation Filtered",
                           events={ecodes.EV_KEY: list(range(0, 768))})
        
        self.state = IDLE
        self.buffer = []
        self.timeout_task = None
        
    def grab_devices(self):
        """Grab both devices so raw events don't reach other consumers."""
        self.kbd_dev.grab()
        self.consumer_dev.grab()
        
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

    async def read_device(self, device):
        """Read events from a device and process them."""
        async for ev in device.async_read_loop():
            self.process_event(ev)
            
    async def run(self):
        """Main event loop — read from both devices concurrently."""
        self.grab_devices()
        print(f"Grabbed devices, filter active. Virtual device: {self.uinput.device.path}", 
              flush=True)
        
        await asyncio.gather(
            self.read_device(self.kbd_dev),
            self.read_device(self.consumer_dev),
        )


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <kbd_device> <consumer_device>")
        print(f"  e.g. {sys.argv[0]} /dev/input/event0 /dev/input/event2")
        sys.exit(1)
        
    kbd_path = sys.argv[1]
    consumer_path = sys.argv[2]
    
    # Verify devices exist
    for path in [kbd_path, consumer_path]:
        if not os.path.exists(path):
            print(f"Error: device {path} not found", file=sys.stderr)
            sys.exit(1)
    
    filt = DictationFilter(kbd_path, consumer_path)
    
    try:
        asyncio.run(filt.run())
    except KeyboardInterrupt:
        pass
    finally:
        try:
            filt.kbd_dev.ungrab()
            filt.consumer_dev.ungrab()
        except Exception:
            pass


if __name__ == "__main__":
    main()
