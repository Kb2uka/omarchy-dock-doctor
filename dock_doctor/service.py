"""One bounded observer, owned by the plugin's stdin/stdout connection."""

import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time

from .discovery import scan
from .state import Store, changes, compare, timestamp, MAX_EVENTS
from . import files


class Observer:
    def __init__(self, store, scanner=scan):
        self.store, self.scanner = store, scanner
        self.devices = []
        self.started = False
        self.scan_error = ""
        self.observed_at = ""
        self.observation = ""

    def refresh(self):
        try:
            devices = self.scanner()
            now = timestamp()
            events = changes(self.devices, devices, now) if self.started and self.store.recording else []
            if events:
                self.store.events = (self.store.events + events)[-MAX_EVENTS:]
                removed = [e for e in events if e["type"] == "disconnect" and e["parent"]]
                parents = {e["parent"] for e in removed}
                if len(removed) > 1 and len(parents) == 1:
                    parent = next((d["name"] for d in self.devices if d["id"] in parents), "one USB parent")
                    self.observation = f"{len(removed)} devices disappeared in the same scan and share {parent}."
                else:
                    self.observation = ""
            if events or (self.store.error and not self.store.read_error):
                try:
                    self.store.save()
                except (OSError, ValueError):
                    # Store retains a bounded error; transient writes retry on the next scan.
                    pass
            self.devices, self.started, self.scan_error, self.observed_at = devices, True, "", now
        except (OSError, ValueError) as error:
            self.scan_error = "USB scan unavailable: " + str(error)
            # Re-establish a fresh reference after a gap; do not infer hotplugs during it.
            self.started = False

    def snapshot(self):
        old = self.store.baseline["devices"] if self.store.baseline else []
        keys = {d["key"] for d in self.devices}
        missing = [dict(d, speed=None, baselineSpeed=d["speed"], comparison="Not connected")
                   for d in old if d["key"] not in keys and not d["controller"]]
        return {"kind": "snapshot", "devices": compare(self.devices, self.store.baseline),
                "missingDevices": missing if self.started else [],
                "events": self.store.events, "baselineAt": self.store.baseline["at"] if self.store.baseline else "",
                "recording": self.store.recording, "observedAt": self.observed_at,
                "observation": self.observation, "error": self.scan_error or self.store.error,
                "ready": self.started and not self.scan_error}

    def command(self, value):
        if not isinstance(value, dict) or set(value) - {"action", "enabled"}:
            raise ValueError("Unsupported command")
        action = value.get("action")
        if action == "save-baseline":
            self.refresh()
            if not self.started or not self.devices:
                raise ValueError("A fresh non-empty USB inventory is required")
            self.store.save_baseline(self.devices)
            return "Working baseline saved"
        if action == "export":
            return "Report saved: " + self.store.export(self.snapshot())
        if action == "recording" and type(value.get("enabled")) is bool:
            previous = self.store.recording
            self.store.recording = value["enabled"]
            try:
                self.store.save()
            except (OSError, ValueError):
                self.store.recording = previous
                raise
            self.started = False
            return "History recording " + ("enabled" if self.store.recording else "paused")
        if action == "clear-events":
            previous = self.store.events
            self.store.events = []
            try:
                self.store.save()
            except (OSError, ValueError):
                self.store.events = previous
                raise
            self.observation = ""
            return "Event history cleared"
        if action == "refresh":
            self.refresh()
            return "USB inventory refreshed" if self.started else self.scan_error
        raise ValueError("Unsupported command")


def emit(value):
    print(json.dumps(value, ensure_ascii=True, allow_nan=False), flush=True)


def watch(observer):
    selector = selectors.DefaultSelector()
    selector.register(sys.stdin.fileno(), selectors.EVENT_READ, "command")
    monitor = None
    try:
        try:
            monitor = subprocess.Popen(["/usr/bin/udevadm", "monitor", "--udev", "--subsystem-match=usb"],
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                       env={"PATH": "/usr/bin:/bin", "LANG": "C"}, start_new_session=True)
            selector.register(monitor.stdout, selectors.EVENT_READ, "udev")
        except OSError:
            pass
        buffer = b""
        due = 0.0
        while True:
            now = time.monotonic()
            if now >= due:
                observer.refresh()
                emit(observer.snapshot())
                due = now + 2.0
            for key, _ in selector.select(max(0, due - time.monotonic())):
                block = os.read(key.fd, 4096)
                if key.data == "udev":
                    if not block:
                        selector.unregister(key.fileobj)
                    else:
                        due = min(due, time.monotonic() + 0.1)
                    continue
                if not block:
                    return
                buffer += block
                if len(buffer) > 8192:
                    raise ValueError("Command input exceeds the size limit")
                while b"\n" in buffer:
                    line, buffer = buffer.split(b"\n", 1)
                    try:
                        message = observer.command(json.loads(line))
                        emit({"kind": "result", "ok": True, "message": message})
                    except (OSError, ValueError, TypeError) as error:
                        emit({"kind": "result", "ok": False, "message": str(error)[:400]})
                    emit(observer.snapshot())
    finally:
        selector.close()
        if monitor is not None:
            if monitor.poll() is None:
                monitor.terminate()
                try:
                    monitor.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    monitor.kill()
                    monitor.wait(timeout=1)
            if monitor.stdout:
                monitor.stdout.close()


def main():
    if sys.platform != "linux" or sys.version_info < (3, 11):
        raise SystemExit("Dock Doctor requires Linux and Python 3.11 or newer")
    mode = sys.argv[1] if len(sys.argv) == 2 else ""
    if mode not in ("watch", "scan"):
        raise SystemExit("Usage: dock-doctor.py scan|watch")
    if mode == "scan":
        emit({"devices": scan(), "observedAt": timestamp()})
        return
    base = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    try:
        def stop(signum, frame):
            raise KeyboardInterrupt
        signal.signal(signal.SIGTERM, stop)
        with files.exclusive_lock(base / "dock-doctor/observer.lock"):
            observer = Observer(Store(base / "dock-doctor"))
            watch(observer)
    except (BrokenPipeError, KeyboardInterrupt):
        pass
    except (OSError, ValueError) as error:
        emit({"kind": "result", "ok": False, "message": "Observer unavailable: " + str(error)[:250]})
