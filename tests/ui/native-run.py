"""Run the native fixture and verify its observed child processes also exit."""

import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time


def descendants(pid):
    pending, seen = [pid], set()
    while pending:
        parent = pending.pop()
        try:
            children = Path(f"/proc/{parent}/task/{parent}/children").read_text().split()
        except FileNotFoundError:
            continue
        for value in children:
            child = int(value)
            if child not in seen:
                seen.add(child)
                if len(seen) > 128:
                    raise RuntimeError("Unexpected native fixture process count")
                pending.append(child)
                yield child


def run(harness, log):
    tracked = {}
    with open(log, "w") as output:
        process = subprocess.Popen(["quickshell", "-p", harness, "--no-color"],
                                   stdout=output, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 20
            while process.poll() is None:
                current_observers = 0
                for pid in descendants(process.pid):
                    try:
                        argv = Path(f"/proc/{pid}/cmdline").read_bytes().split(b"\0")
                        role = ("observer" if any(a.endswith(b"/dock-doctor.py") for a in argv)
                                else "monitor" if argv[:2] == [b"/usr/bin/udevadm", b"monitor"] else "")
                        if role == "observer":
                            current_observers += 1
                        if role and pid not in tracked:
                            tracked[pid] = (role, os.pidfd_open(pid))
                    except ProcessLookupError:
                        pass
                    except FileNotFoundError:
                        pass
                if current_observers > 1:
                    raise RuntimeError("Multiple observer processes started in one shell")
                if time.monotonic() >= deadline:
                    raise RuntimeError("Native fixture did not exit")
                time.sleep(0.02)
            if process.returncode != 0:
                raise RuntimeError(f"Native fixture failed: {process.returncode}")
            expected = {"observer"}
            if os.access("/usr/bin/udevadm", os.X_OK):
                expected.add("monitor")
            roles = {role for role, _ in tracked.values()}
            if not expected.issubset(roles):
                raise RuntimeError(f"Native fixture did not observe: {expected - roles}")
            for role, fd in tracked.values():
                if not select.select([fd], [], [], 2)[0]:
                    raise RuntimeError(f"Native {role} survived shell shutdown")
            print("Native lifecycle: observer and available event monitor exited with the shell")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            for _, fd in tracked.values():
                if not select.select([fd], [], [], 0)[0]:
                    signal.pidfd_send_signal(fd, signal.SIGKILL)
                os.close(fd)


if __name__ == "__main__":
    run(sys.argv[1], sys.argv[2])
