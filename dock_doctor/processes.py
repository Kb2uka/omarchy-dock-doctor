"""Tie the optional USB event monitor to its observer's lifetime on Linux."""

import ctypes
import os
import signal

PR_SET_PDEATHSIG = 1


def parent_death_binding():
    """Prepare a pre-exec callback for the single-threaded observer process."""
    parent = os.getpid()
    # Resolve libc before fork; the observer does not create Python threads.
    prctl = ctypes.CDLL(None, use_errno=True).prctl
    prctl.argtypes = [ctypes.c_int, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_ulong]
    prctl.restype = ctypes.c_int

    def bind():
        if prctl(PR_SET_PDEATHSIG, signal.SIGKILL, 0, 0, 0) != 0:
            os._exit(126)
        # Cover a parent that died between fork and installing the binding.
        if os.getppid() != parent:
            os._exit(126)

    return bind
