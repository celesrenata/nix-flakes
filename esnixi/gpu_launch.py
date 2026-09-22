"""Acquire GPU ownership before the server loads any CUDA model weights."""
import fcntl
import os
import sys

fd = os.open(os.environ["ARCANE_GPU_LOCK"], os.O_RDWR)
fcntl.flock(fd, fcntl.LOCK_EX)
os.set_inheritable(fd, True)
os.environ["ARCANE_GPU_LOCK_FD"] = str(fd)
os.execvp(sys.argv[1], sys.argv[1:])
