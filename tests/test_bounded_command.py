import subprocess
import sys
import time
import unittest
from pathlib import Path

HELPER = Path(__file__).resolve().parent.parent / "scripts" / "bounded-command.py"


class BoundedCommandTests(unittest.TestCase):
    def run_helper(self, timeout_ms, *command):
        return subprocess.run(
            [sys.executable, "-B", str(HELPER), str(timeout_ms), *command],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=5,
        )

    def test_passes_through_bounded_success_output(self):
        result = self.run_helper(
            1000, sys.executable, "-c", "import sys; print('olá'); print('aviso', file=sys.stderr)"
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "olá\n".encode())
        self.assertEqual(result.stderr, "aviso\n".encode())

    def test_kills_command_after_deadline(self):
        started = time.monotonic()
        result = self.run_helper(200, sys.executable, "-c", "import time; time.sleep(20)")
        self.assertEqual(result.returncode, 124)
        self.assertIn(b"time limit", result.stderr)
        self.assertLess(time.monotonic() - started, 2.5)

    def test_stops_command_that_exceeds_output_budget(self):
        result = self.run_helper(
            2000, sys.executable, "-c", "import sys; sys.stdout.write('x' * 1000000); sys.stdout.flush()"
        )
        self.assertEqual(result.returncode, 125)
        self.assertLessEqual(len(result.stdout), 64 * 1024)
        self.assertIn(b"output limit", result.stderr)


if __name__ == "__main__":
    unittest.main()
