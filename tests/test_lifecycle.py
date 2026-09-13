import json
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import unittest


class LifecycleTests(unittest.TestCase):
    def launch(self, directory):
        source = str(Path(__file__).resolve().parents[1])
        code = """
import sys, subprocess
sys.path.insert(0, sys.argv[1])
from dock_doctor import service
from tests_fixture import fixture
service.scan = lambda: fixture
service.Observer.__init__.__defaults__ = (service.scan,)
original = subprocess.Popen
def monitor(*args, **kwargs):
    process = original([sys.executable, "-c", "import time; time.sleep(60)"], **kwargs)
    print(process.pid, file=sys.stderr, flush=True)
    return process
service.subprocess.Popen = monitor
sys.argv = ["dock-doctor.py", "watch"]
service.main()
"""
        fixture = Path(directory) / "tests_fixture.py"
        fixture.write_text("fixture = []\n")
        # The fixture directory is explicitly selected; no user module search path.
        code = code.replace('sys.path.insert(0, sys.argv[1])',
                            'sys.path[:0] = [sys.argv[1], sys.argv[2]]')
        return subprocess.Popen([sys.executable, "-I", "-c", code, source, directory],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                env={"HOME":str(Path.home()), "XDG_STATE_HOME":directory, "PATH":"/usr/bin:/bin"})

    def test_eof_stops_observer_and_its_monitor(self):
        with tempfile.TemporaryDirectory() as directory:
            process = self.launch(directory)
            output, error = process.communicate(b'{"action":"export"}\n', timeout=5)
            self.assertEqual(process.returncode, 0, error)
            messages = [json.loads(line) for line in output.splitlines()]
            self.assertTrue(any(m.get("ok") is True for m in messages))
            pid = int(error.strip())
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)

    def test_sigterm_stops_monitor_and_releases_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            process = self.launch(directory)
            try:
                self.assertTrue(select.select([process.stdout], [], [], 5)[0])
                self.assertEqual(json.loads(process.stdout.readline())["kind"], "snapshot")
                process.terminate()
                _, error = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 0, error)
                with self.assertRaises(ProcessLookupError):
                    os.kill(int(error.strip()), 0)
                successor = self.launch(directory)
                output, error = successor.communicate(timeout=5)
                self.assertEqual(json.loads(output.splitlines()[0])["kind"], "snapshot", error)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()
