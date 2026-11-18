"""Exercise the real unlock function with inert PAM/compositor substitutes."""

import re
import shutil
import subprocess
import unittest
from pathlib import Path


@unittest.skipUnless(shutil.which("node"), "Node is needed to execute the QML JavaScript")
class LockAuthTest(unittest.TestCase):
    def test_only_success_in_a_secure_locked_session_releases_the_lock(self):
        source = (Path(__file__).resolve().parents[1] / "lockscreen/LockAuth.qml").read_text()
        match = re.search(r"    function unlock\(result\) \{(.*?)\n    \}", source, re.S)
        self.assertIsNotNone(match)
        script = """
const assert = require('node:assert/strict');
const PamResult = {Success: 0, Failed: 1, MaxTries: 2, Error: 3};
for (const secure of [false, true]) {
  for (const locked of [false, true]) {
    for (const result of [0, 1, 2, 3, null, undefined, '0']) {
      const sessionLock = {secure, locked};
      let status = '', cleared = 0, inputCleared = 0, aborted = 0, quit = 0;
      const clearPendingPassword = () => cleared++;
      const clearInputRequested = () => inputCleared++;
      const fingerprintPam = {abort: () => aborted++};
      const passwordPam = {abort: () => aborted++};
      const Qt = {quit: () => quit++, callLater: callback => callback()};
      function unlock(result) { BODY }
      const allowed = result === PamResult.Success && secure && locked;
      assert.equal(unlock(result), allowed);
      assert.equal(sessionLock.locked, allowed ? false : locked);
      assert.equal(cleared, allowed ? 1 : 0);
      assert.equal(inputCleared, allowed ? 1 : 0);
      assert.equal(aborted, allowed ? 2 : 0);
      assert.equal(quit, allowed ? 1 : 0);
    }
  }
}
""".replace("BODY", match.group(1))
        subprocess.run([shutil.which("node"), "-e", script], check=True, capture_output=True)


if __name__ == "__main__":
    unittest.main()
