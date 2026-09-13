"""Bounded USB sysfs reads; no hardware control operations."""

import hashlib
import math
import os
from pathlib import Path
import re
import stat

DEVICE = re.compile(r"(?:usb[0-9]+|[0-9]+-[0-9]+(?:\.[0-9]+)*)\Z")
CLASSES = {"01": ("audio", "Audio Interface"), "03": ("keyboard", "HID Device"),
           "08": ("storage", "Mass Storage"), "09": ("hub", "USB Hub"),
           "0e": ("camera", "USB Camera")}
MAX_DEVICES = 256


def clean(value):
    return " ".join("".join(c for c in value if c.isprintable()).split())[:120]


def attribute(path):
    """Attributes are kernel-created regular files, read once with a fixed cap."""
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise ValueError("Unexpected USB attribute type")
        return clean(os.read(fd, 512).decode("utf-8", "replace"))
    finally:
        os.close(fd)


def optional(path):
    try:
        return attribute(path)
    except FileNotFoundError:
        return ""


def numeric(value):
    try:
        result = float(value)
        return result if math.isfinite(result) and 0 < result <= 1000000 else None
    except (TypeError, ValueError):
        return None


def scan(root=Path("/sys/bus/usb/devices"), device_root=Path("/sys/devices")):
    result = []
    names = sorted(p.name for p in root.iterdir() if DEVICE.fullmatch(p.name))
    if len(names) > MAX_DEVICES:
        raise ValueError("USB inventory exceeds the supported 256 devices")
    for name in names:
        try:
            path = (root / name).resolve(strict=True)
            if not path.is_relative_to(device_root.resolve(strict=True)):
                raise ValueError("USB path escapes the kernel device tree")
            vendor = attribute(path / "idVendor").lower()
            product = attribute(path / "idProduct").lower()
            if not re.fullmatch(r"[0-9a-f]{4}", vendor + "") or not re.fullmatch(r"[0-9a-f]{4}", product):
                raise ValueError("Invalid USB vendor/product ID")
            serial = optional(path / "serial")
            title = optional(path / "product")
            manufacturer = optional(path / "manufacturer")
            cls = optional(path / "bDeviceClass").lower()
            classes = {cls}
            for interface in list(path.iterdir())[:128]:
                if interface.name.startswith(name + ":") and interface.is_dir() and not interface.is_symlink():
                    classes.add(optional(interface / "bInterfaceClass").lower())
            kind, category = next((CLASSES[c] for c in ("09", "0e", "01", "08", "03") if c in classes),
                                  ("device", "USB Device"))
            controller = name.startswith("usb")
            if controller:
                kind, category = "controller", "USB Root Hub"
            elif "keyboard" in title.lower():
                kind, category = "keyboard", "HID Keyboard"
            parent = "" if controller else name.rsplit(".", 1)[0] if "." in name else "usb" + name.split("-")[0]
            # Controller identity is its stable physical sysfs path, not its bus number.
            controller_path = str(path).split("/usb", 1)[0]
            port = name.split("-", 1)[-1] if not controller else "root"
            identity = f"{vendor}:{product}:serial:{serial}" if serial else f"{vendor}:{product}:port:{controller_path}:{port}"
            result.append({"id": name, "key": hashlib.sha256(identity.encode()).hexdigest(),
                           "parent": parent, "name": "USB bus " + name[3:] if controller else title or "USB Device",
                           "kind": kind, "category": category, "speed": numeric(optional(path / "speed")),
                           "vendor": vendor, "productId": product, "manufacturer": manufacturer,
                           "product": title, "serial": serial, "identityBasis": "serial" if serial else "port",
                           "controller": controller, "ambiguous": False})
        except FileNotFoundError:
            # Hot-unplug during enumeration: omit the disappearing device.
            continue
    for item in result:
        item["ambiguous"] = sum(d["key"] == item["key"] for d in result) != 1
    return result
