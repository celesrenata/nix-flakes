"""Cross-container NVIDIA ownership; release only after GPU weights unload."""
import asyncio
import fcntl
import os


class GPULease:
    def __init__(self, path, inherited_fd=None):
        self.fd = inherited_fd if inherited_fd is not None else os.open(path, os.O_RDWR)
        self.held = inherited_fd is not None

    async def acquire(self):
        while not self.held:
            try:
                fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.held = True
            except BlockingIOError:
                await asyncio.sleep(.1)

    def acquire_blocking(self):
        if not self.held:
            fcntl.flock(self.fd, fcntl.LOCK_EX)
            self.held = True

    def release(self):
        if self.held:
            fcntl.flock(self.fd, fcntl.LOCK_UN)
            self.held = False

    @classmethod
    def from_environment(cls):
        path = os.environ.get("ARCANE_GPU_LOCK")
        fd = os.environ.get("ARCANE_GPU_LOCK_FD")
        return cls(path, int(fd) if fd else None) if path else None
