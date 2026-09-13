"""Bounded state, conservative comparison, and private report exports."""

from datetime import datetime, timezone
import json
from pathlib import Path
import secrets

from . import files

MAX_EVENTS = 300


def timestamp():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def encode(data):
    return json.dumps(data, ensure_ascii=True, allow_nan=False).encode()


def validate_inventory(devices):
    if not isinstance(devices, list) or len(devices) > 256:
        raise ValueError("Invalid saved USB inventory")
    for item in devices:
        if not isinstance(item, dict):
            raise ValueError("Invalid saved device")
        for key in ("id", "key", "parent", "name", "kind", "category", "vendor", "productId",
                    "manufacturer", "product", "serial", "identityBasis"):
            if not isinstance(item.get(key), str) or len(item[key]) > 160:
                raise ValueError("Invalid saved device field")
        if type(item.get("ambiguous")) is not bool or type(item.get("controller")) is not bool:
            raise ValueError("Invalid saved device flags")
        speed = item.get("speed")
        if speed is not None and (type(speed) not in (int, float) or not 0 < speed <= 1000000):
            raise ValueError("Invalid saved link speed")
    return devices


class Store:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.baseline = None
        self.events = []
        self.recording = True
        self.error = ""
        try:
            data = files.read_file(self.directory / "state.json")
            if data:
                value = json.loads(data)
                if not isinstance(value, dict) or value.get("version") != 1:
                    raise ValueError("Unsupported saved state")
                baseline = value.get("baseline")
                if baseline is not None:
                    if not isinstance(baseline, dict) or not isinstance(baseline.get("at"), str):
                        raise ValueError("Invalid baseline")
                    validate_inventory(baseline.get("devices"))
                events = value.get("events")
                if not isinstance(events, list) or len(events) > MAX_EVENTS:
                    raise ValueError("Invalid saved events")
                for event in events:
                    if not isinstance(event, dict) or any(not isinstance(event.get(k), str) or len(event[k]) > 240
                                                         for k in ("at", "event", "details", "type", "parent")):
                        raise ValueError("Invalid saved event")
                if type(value.get("recording")) is not bool:
                    raise ValueError("Invalid recording setting")
                self.baseline, self.events, self.recording = baseline, events, value["recording"]
        except (OSError, ValueError, TypeError) as error:
            self.error = "Saved state could not be read: " + str(error)

    def save(self):
        if self.error:
            raise ValueError(self.error + ". Retained file was left untouched.")
        files.atomic_write(self.directory / "state.json", encode({"version": 1, "baseline": self.baseline,
                           "events": self.events, "recording": self.recording}))

    def save_baseline(self, devices):
        previous = self.baseline
        self.baseline = {"at": timestamp(), "devices": validate_inventory(devices)}
        try:
            self.save()
        except (OSError, ValueError):
            self.baseline = previous
            raise

    def export(self, snapshot):
        # Raw USB serial numbers and stable identity hashes stay out of shared reports.
        def redact(value):
            if isinstance(value, dict):
                return {k: redact(v) for k, v in value.items() if k not in ("serial", "key")}
            if isinstance(value, list):
                return [redact(v) for v in value]
            return value
        path = self.directory / ("report-" + secrets.token_hex(8) + ".json")
        files.atomic_write(path, encode(redact(snapshot)))
        return str(path)


def compare(devices, baseline):
    old = baseline["devices"] if baseline else []
    rows = []
    for device in devices:
        matches = [d for d in old if d["key"] == device["key"] and not d["ambiguous"]]
        prior = matches[0] if len(matches) == 1 and not device["ambiguous"] else None
        a, b = device["speed"], prior["speed"] if prior else None
        change = "No baseline" if not baseline else "Not matched" if prior is None else "Not reported" if a is None or b is None else "Lower link speed" if a < b else "Higher link speed" if a > b else "Unchanged"
        rows.append(dict(device, baselineSpeed=b, comparison=change,
                         matchBasis=device["identityBasis"] if prior else ""))
    return rows


def changes(before, after, at):
    old, new = {d["id"]: d for d in before}, {d["id"]: d for d in after}
    events = []
    for kind, source, target in (("disconnect", old, new), ("connect", new, old)):
        for key, device in source.items():
            other = target.get(key)
            if other is not None and other["key"] == device["key"]:
                continue
            if device["controller"]:
                continue
            parent = source.get(device["parent"], {})
            events.append({"at": at, "type": kind, "parent": device["parent"],
                           "event": device["name"] + (" disconnected" if kind == "disconnect" else " connected"),
                           "details": device["category"] + " (via " + parent.get("name", "unreported parent") + ")"})
    for key in old.keys() & new.keys():
        a, b = old[key], new[key]
        if a["key"] == b["key"] and a["speed"] != b["speed"] and not b["controller"]:
            events.append({"at": at, "type": "change", "parent": b["parent"],
                           "event": b["name"] + " link changed", "details": "Negotiated link speed changed"})
    return events
