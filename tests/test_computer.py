from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from dock_doctor import discovery


class ComputerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.dmi = self.root / "dmi"
        self.dmi.mkdir()
        self.model = self.root / "model"

    def read(self):
        return discovery.computer_info(self.dmi, self.model, hostname="")

    def test_reports_computer_model_without_serial(self):
        (self.dmi / "product_name").write_text("XPS 16 DA16260\n")
        (self.dmi / "sys_vendor").write_text("Dell Inc.\n")
        (self.dmi / "product_serial").write_text("private")
        self.assertEqual(self.read(), {"name": "XPS 16 DA16260", "model": "XPS 16 DA16260", "manufacturer": "Dell Inc."})

    def test_device_tree_model_and_missing_metadata(self):
        self.assertEqual(self.read()["name"], "This computer")
        self.model.write_bytes(b"Raspberry Pi 5 Model B\x00")
        self.assertEqual(self.read()["name"], "Raspberry Pi 5 Model B")

    def test_metadata_is_bounded_and_cannot_follow_attribute_symlink(self):
        secret = self.root / "secret"
        secret.write_text("secret")
        (self.dmi / "product_name").symlink_to(secret)
        self.assertEqual(self.read()["name"], "This computer")
        (self.dmi / "product_name").unlink()
        (self.dmi / "product_name").write_text("X" * 10000)
        self.assertEqual(len(self.read()["name"]), 120)

    def test_denied_metadata_keeps_generic_computer_name(self):
        with patch.object(discovery, "attribute", side_effect=PermissionError()):
            self.assertEqual(self.read()["name"], "This computer")

    def test_configured_machine_name_is_detected_for_any_machine(self):
        (self.dmi / "product_name").write_text("ThinkPad T14")
        with patch.object(discovery.os, "uname") as uname:
            uname.return_value.nodename = "studio-laptop"
            info = discovery.computer_info(self.dmi, self.model)
        self.assertEqual(info["name"], "studio-laptop")
        self.assertEqual(info["model"], "ThinkPad T14")

    def test_computer_metadata_does_not_become_a_usb_device(self):
        from dock_doctor.service import Observer
        from dock_doctor.state import Store
        observer = Observer(Store(self.root / "state"), scanner=lambda: [],
                            computer={"name": "studio-laptop", "model": "ThinkPad T14"})
        observer.refresh()
        snapshot = observer.snapshot()
        self.assertEqual(snapshot["computer"]["name"], "studio-laptop")
        self.assertEqual(snapshot["devices"], [])
        self.assertEqual(snapshot["events"], [])
