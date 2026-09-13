"""Keep native process assertions accurate across an observer handoff."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("native_runner", Path(__file__).parent / "ui/native-run.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class NativeRunnerTests(unittest.TestCase):
    def check_handoff(self, overlap, signal_error=None, restart=False):
        self.closed = []
        process = Mock(pid=10, returncode=0)
        process.poll.side_effect = [None, 0, 0]
        exited = set()

        def children(pid):
            yield 101
            # The prior observer exits between two /proc directory reads.
            if not overlap:
                exited.add(101)
            yield 102

        def ready(fds, write, error, timeout):
            if timeout:
                exited.update(fds)
            return [fd for fd in fds if fd in exited], [], []

        with tempfile.TemporaryDirectory() as directory, \
                patch.object(runner.subprocess, "Popen", return_value=process), \
                patch.object(runner, "descendants", side_effect=children), \
                patch.object(runner.Path, "read_bytes", return_value=b"python3\0/dock-doctor.py\0watch\0"), \
                patch.object(runner.os, "pidfd_open", side_effect=lambda pid: pid), \
                patch.object(runner.os, "close", side_effect=self.closed.append), \
                patch.object(runner.os, "access", return_value=False), \
                patch.object(runner.select, "select", side_effect=ready), \
                patch.object(runner.signal, "pidfd_send_signal", side_effect=signal_error), \
                patch.object(runner.Path, "read_text", return_value="REQUEST_OBSERVER_RESTART" if restart else ""), \
                patch.object(runner.time, "sleep"), \
                patch.object(runner.time, "monotonic", return_value=0):
            runner.run("fixture", str(Path(directory) / "native.log"))

    def test_exited_observer_does_not_count_as_overlap(self):
        self.check_handoff(overlap=False)

    def test_two_live_observers_still_fail(self):
        with self.assertRaisesRegex(RuntimeError, "Multiple observer"):
            self.check_handoff(overlap=True)

    def test_cleanup_exit_race_preserves_failure_and_closes_every_fd(self):
        with self.assertRaisesRegex(RuntimeError, "Multiple observer"):
            self.check_handoff(overlap=True, signal_error=ProcessLookupError())
        self.assertEqual(self.closed, [101, 102])

    def test_exit_before_injection_is_an_explicit_failure(self):
        with self.assertRaisesRegex(RuntimeError, "Observer exited before restart injection"):
            self.check_handoff(overlap=False, signal_error=ProcessLookupError(), restart=True)
        self.assertEqual(self.closed, [101, 102])
