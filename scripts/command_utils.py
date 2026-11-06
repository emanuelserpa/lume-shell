"""Small subprocess helpers shared by standalone backend scripts."""
import subprocess


def run_command(
    args,
    timeout=20,
    *,
    strip_output=True,
    error_code=1,
    timeout_code=124,
    timeout_message="tempo esgotado",
):
    """Run a bounded command while preserving each caller's result contract."""
    try:
        proc = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
        )
        stdout, stderr = proc.stdout or "", proc.stderr or ""
        if strip_output:
            stdout, stderr = stdout.strip(), stderr.strip()
        return proc.returncode, stdout, stderr
    except subprocess.TimeoutExpired as exc:
        if timeout_code is None:
            return error_code, "", str(exc)
        return timeout_code, "", timeout_message
    except Exception as exc:  # noqa: BLE001
        return error_code, "", str(exc)
