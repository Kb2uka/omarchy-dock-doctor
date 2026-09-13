import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from dock_doctor import files
from dock_doctor.discovery import scan, numeric, clean
from dock_doctor.service import Observer
from dock_doctor.state import Store, compare, changes, validate_inventory


def device(name="1-1", parent="usb1", speed=480):
    return dict(id=name, key=name, parent=parent, name="Test device", kind="storage",
                category="Mass Storage", speed=speed, baselineSpeed=None, vendor="1234",
                productId="5678", manufacturer="", product="", serial="secret-serial",
                identityBasis="serial", ambiguous=False, controller=False)


class DiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bus = self.root / "bus"
        self.tree = self.root / "devices"
        self.bus.mkdir()
        self.tree.mkdir()

    def add(self, name, cls="00", speed="480", serial=""):
        path = self.tree / "pci0000:00" / "usb1" / name
        path.mkdir(parents=True, exist_ok=True)
        for key, value in dict(idVendor="1234", idProduct="5678", bDeviceClass=cls,
                               speed=speed, serial=serial, product="USB Device").items():
            (path / key).write_text(value)
        (self.bus / name).symlink_to(path)
        return path

    def scan(self):
        return scan(self.bus, self.tree)

    def test_parent_relationship_and_link_speed(self):
        self.add("1-2.3", "08", "5000")
        d = self.scan()[0]
        self.assertEqual((d["parent"], d["kind"], d["speed"]), ("1-2", "storage", 5000))

    def test_root_controller_and_audio_interface(self):
        self.add("usb1", "09", "10000")
        self.add("1-1", "01")
        d = {x["id"]: x for x in self.scan()}
        self.assertTrue(d["usb1"]["controller"])
        self.assertEqual(d["1-1"]["kind"], "audio")
        self.assertEqual(d["1-1"]["parent"], "usb1")

    def test_interface_class_identifies_composite_webcam(self):
        path = self.add("1-2")
        (path / "1-2:1.0").mkdir()
        (path / "1-2:1.0/bInterfaceClass").write_text("0e")
        self.assertEqual(self.scan()[0]["kind"], "camera")

    def test_disappearing_device_omitted(self):
        path = self.add("1-1")
        (path / "idVendor").unlink()
        self.assertEqual(self.scan(), [])

    def test_no_serial_identity_is_port_specific(self):
        self.add("1-1")
        self.add("1-2")
        a, b = self.scan()
        self.assertNotEqual(a["key"], b["key"])
        self.assertEqual(a["identityBasis"], "port")

    def test_serial_identity_follows_port_move(self):
        self.add("1-1", serial="unique")
        a = self.scan()[0]
        (self.bus / "1-1").unlink()
        self.add("1-2", serial="unique")
        self.assertEqual(a["key"], self.scan()[0]["key"])

    def test_duplicate_serial_is_ambiguous(self):
        self.add("1-1", serial="duplicate")
        self.add("1-2", serial="duplicate")
        self.assertTrue(all(d["ambiguous"] for d in self.scan()))

    def test_sysfs_escape_is_rejected(self):
        (self.bus / "1-1").symlink_to(self.root)
        with self.assertRaises(ValueError):
            self.scan()

    def test_attribute_symlink_is_rejected(self):
        path = self.add("1-1")
        (path / "product").unlink()
        (path / "product").symlink_to("/etc/passwd")
        with self.assertRaises(OSError):
            self.scan()

    def test_fifo_attribute_never_blocks(self):
        path = self.add("1-1")
        (path / "product").unlink()
        os.mkfifo(path / "product")
        with self.assertRaises(ValueError):
            self.scan()

    def test_metadata_is_bounded_and_control_characters_removed(self):
        self.assertEqual(len(clean("x" * 1000)), 120)
        self.assertNotIn("\x1b", clean("evil\x1bname"))

    def test_unknown_nonfinite_and_invalid_speeds(self):
        for value in ("", "unknown", "nan", "inf", "-4", "0", "1000001"):
            self.assertIsNone(numeric(value))

    def test_inventory_limit_fails_explicitly(self):
        self.add("1-1")
        with patch("dock_doctor.discovery.MAX_DEVICES", 0), self.assertRaises(ValueError):
            self.scan()


class StateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "state"
        self.store = Store(self.path)

    def test_baseline_roundtrip_and_private_permissions(self):
        self.store.save_baseline([device()])
        self.assertEqual(Store(self.path).baseline["devices"][0]["speed"], 480)
        self.assertEqual((self.path / "state.json").stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o700)

    def test_corrupt_state_is_not_overwritten(self):
        self.path.mkdir()
        target = self.path / "state.json"
        target.write_text("corrupt")
        store = Store(self.path)
        self.assertTrue(store.error)
        with self.assertRaises(ValueError):
            store.save_baseline([device()])
        self.assertEqual(target.read_text(), "corrupt")
        self.assertIsNone(store.baseline)

    def test_symlink_state_is_not_followed_or_overwritten(self):
        self.path.mkdir()
        victim = Path(self.temp.name) / "victim"
        victim.write_text("private")
        (self.path / "state.json").symlink_to(victim)
        store = Store(self.path)
        self.assertTrue(store.error)
        with self.assertRaises(ValueError):
            store.save_baseline([device()])
        self.assertEqual(victim.read_text(), "private")

    def test_baseline_failure_restores_previous_memory(self):
        self.store.save_baseline([device()])
        before = self.store.baseline
        with patch.object(files, "atomic_write", side_effect=OSError("full")):
            with self.assertRaises(OSError):
                self.store.save_baseline([device(speed=5000)])
        self.assertEqual(self.store.baseline, before)

    def test_only_one_observer_can_own_state(self):
        with files.exclusive_lock(self.path / "observer.lock"):
            with self.assertRaises(BlockingIOError):
                with files.exclusive_lock(self.path / "observer.lock"):
                    pass
        with files.exclusive_lock(self.path / "observer.lock"):
            pass

    def test_observer_lock_rejects_symlinks(self):
        self.path.mkdir()
        victim = Path(self.temp.name) / "victim"
        victim.write_text("private")
        (self.path / "observer.lock").symlink_to(victim)
        with self.assertRaises(OSError):
            with files.exclusive_lock(self.path / "observer.lock"):
                pass
        self.assertEqual(victim.read_text(), "private")

    def test_export_redacts_nested_serials_and_keys(self):
        path = self.store.export({"devices": [device()], "extra": {"key": "secret", "serial": "secret"}})
        text = Path(path).read_text()
        self.assertNotIn("secret", text)
        self.assertNotIn('"key"', text)
        self.assertNotIn('"serial":', text)
        self.assertEqual(Path(path).stat().st_mode & 0o777, 0o600)

    def test_baseline_rejects_nonfinite_and_malformed_fields(self):
        for field, value in (("speed", float("nan")), ("speed", True), ("name", ["bad"]), ("key", "x"*200)):
            d = device()
            d[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate_inventory([d])

    def test_comparison_is_not_a_health_diagnosis(self):
        old = {"devices": [device(speed=5000)]}
        row = compare([device()], old)[0]
        self.assertEqual(row["comparison"], "Lower link speed")
        self.assertEqual(row["baselineSpeed"], 5000)
        self.assertNotIn("health", row)
        self.assertEqual(compare([device()], {"devices": [device()]})[0]["comparison"], "Unchanged")

    def test_unmatched_or_ambiguous_devices_never_compare(self):
        old = {"devices": [device("different")]}
        self.assertEqual(compare([device()], old)[0]["comparison"], "Not matched")
        d = device()
        d["ambiguous"] = True
        self.assertIsNone(compare([d], {"devices": [device()]})[0]["baselineSpeed"])

    def test_duplicate_baseline_keys_do_not_match(self):
        self.assertEqual(compare([device()], {"devices": [device(), device()]})[0]["comparison"], "Not matched")

    def test_unknown_speed_is_explicit(self):
        self.assertEqual(compare([device(speed=None)], {"devices": [device()]})[0]["comparison"], "Not reported")


class ObserverTests(unittest.TestCase):
    setUp = StateTests.setUp
    def make(self, devices):
        return Observer(self.store, scanner=lambda:copy.deepcopy(devices))

    def test_initial_inventory_is_not_hotplug_history(self):
        observer = self.make([device()])
        observer.refresh()
        observer.refresh()
        self.assertEqual(self.store.events, [])

    def test_shared_parent_observation_is_conservative(self):
        hub = device("1-1", "usb1", 5000)
        hub["name"] = "Desk Hub"
        current = [hub, device("1-1.1", "1-1"), device("1-1.2", "1-1")]
        observer = self.make(current)
        observer.refresh()
        current[:] = [hub]
        observer.refresh()
        self.assertEqual(len(self.store.events), 2)
        self.assertIn("same scan", observer.observation)
        self.assertIn("Desk Hub", observer.observation)
        self.assertEqual(len(Store(self.path).events), 2)

    def test_scan_failure_preserves_inventory_without_false_disconnect(self):
        observer = self.make([device()])
        observer.refresh()
        observer.scanner = lambda: (_ for _ in ()).throw(PermissionError("denied"))
        observer.refresh()
        self.assertEqual(len(observer.devices), 1)
        self.assertFalse(observer.snapshot()["ready"])
        self.assertEqual(self.store.events, [])
        with self.assertRaises(ValueError):
            observer.command({"action": "save-baseline"})
        observer.scanner = lambda:[]
        observer.refresh()
        self.assertEqual(self.store.events, [])

    def test_recording_pauses_persistently(self):
        current = [device()]
        observer = self.make(current)
        observer.refresh()
        observer.command({"action": "recording", "enabled": False})
        current.clear()
        observer.refresh()
        self.assertEqual(self.store.events, [])
        self.assertFalse(Store(self.path).recording)

    def test_unknown_commands_and_arbitrary_paths_are_rejected(self):
        observer = self.make([])
        for value in ({"action":"reset"}, {"action":"export", "path":"/tmp/target"}, [], {"action":"recording","enabled":"true"}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                observer.command(value)

    def test_empty_inventory_does_not_replace_baseline(self):
        observer = self.make([])
        with self.assertRaises(ValueError):
            observer.command({"action":"save-baseline"})

    def test_replacement_on_same_port_records_two_events(self):
        a, b = device(), device()
        b["key"] = "other"
        self.assertEqual([e["type"] for e in changes([a],[b],"now")], ["disconnect","connect"])

    def test_speed_change_is_recorded_without_disconnect(self):
        events = changes([device(speed=5000)], [device(speed=480)], "now")
        self.assertEqual([e["type"] for e in events], ["change"])

    def test_clear_events_preserves_baseline(self):
        observer = self.make([device()])
        observer.command({"action":"save-baseline"})
        baseline = self.store.baseline
        observer.command({"action":"clear-events"})
        self.assertEqual(self.store.baseline, baseline)
        self.assertEqual(self.store.events, [])

    def test_missing_baseline_device_appears_in_comparison_only(self):
        self.store.save_baseline([device()])
        observer = self.make([])
        observer.refresh()
        snapshot = observer.snapshot()
        self.assertEqual(snapshot["devices"], [])
        self.assertEqual(snapshot["missingDevices"][0]["comparison"], "Not connected")

    def test_history_is_bounded(self):
        current = [device()]
        observer = self.make(current)
        observer.refresh()
        event = dict(at="now",type="connect",parent="",event="Device",details="")
        self.store.events = [event]*300
        current.clear()
        observer.refresh()
        self.assertEqual(len(self.store.events),300)


if __name__ == "__main__":
    unittest.main()
