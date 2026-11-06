#!/usr/bin/env python3
import subprocess
import unittest
from unittest.mock import patch

from tests.helpers import import_script

run_command = import_script("command_utils", "command_utils.py").run_command


class TestRunCommand(unittest.TestCase):
    def test_output_can_be_preserved_or_stripped(self):
        completed = subprocess.CompletedProcess(
            args=["example"], returncode=0, stdout=" output\n", stderr=" warning\n"
        )
        with patch("command_utils.subprocess.run", return_value=completed):
            self.assertEqual(run_command(["example"]), (0, "output", "warning"))
            self.assertEqual(
                run_command(["example"], strip_output=False),
                (0, " output\n", " warning\n"),
            )

    def test_timeout_result_is_configurable(self):
        timeout = subprocess.TimeoutExpired("example", 1)
        with patch("command_utils.subprocess.run", side_effect=timeout):
            self.assertEqual(run_command(["example"]), (124, "", "tempo esgotado"))
            self.assertEqual(run_command(["example"], error_code=127, timeout_code=None)[0], 127)

    def test_execution_error_uses_callers_exit_code(self):
        with patch("command_utils.subprocess.run", side_effect=OSError("missing")):
            self.assertEqual(run_command(["example"], error_code=127), (127, "", "missing"))


if __name__ == "__main__":
    unittest.main()
