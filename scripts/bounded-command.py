#!/usr/bin/env python3
"""Run a query helper with a deadline, process-group cleanup, and bounded output."""

import os
import selectors
import signal
import subprocess
import sys
import time

MAX_OUTPUT_BYTES = 64 * 1024
TERMINATE_GRACE_SECONDS = 0.5
KILL_DRAIN_SECONDS = 1.0


def main(argv):
    if len(argv) < 3:
        os.write(2, b"bounded-command: expected TIMEOUT_MS and COMMAND\n")
        return 2
    try:
        timeout = max(1, int(argv[1])) / 1000
    except ValueError:
        os.write(2, b"bounded-command: invalid timeout\n")
        return 2
    command = argv[2:]
    if not command or not command[0]:
        os.write(2, b"bounded-command: empty command\n")
        return 2

    try:
        process = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
            close_fds=True,
        )
    except OSError as error:
        os.write(2, (str(error) + "\n").encode(errors="replace"))
        return 127

    selector = selectors.DefaultSelector()
    output = {process.stdout: bytearray(), process.stderr: bytearray()}
    names = {process.stdout: "stdout", process.stderr: "stderr"}
    for stream in output:
        os.set_blocking(stream.fileno(), False)
        selector.register(stream, selectors.EVENT_READ)

    deadline = time.monotonic() + timeout
    terminate_at = None
    kill_drain_at = None
    failure = None
    while selector.get_map() or process.poll() is None:
        now = time.monotonic()
        if failure is None and now >= deadline:
            failure = f"command exceeded its {timeout:g} s time limit\n"
            terminate_at = now + TERMINATE_GRACE_SECONDS
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        elif terminate_at is not None and now >= terminate_at:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            terminate_at = None
            kill_drain_at = now + KILL_DRAIN_SECONDS

        if kill_drain_at is not None and now >= kill_drain_at:
            # A daemonized descendant may have escaped the process group while
            # keeping inherited pipes open. Do not let that hold the query open.
            for key in list(selector.get_map().values()):
                selector.unregister(key.fileobj)
                key.fileobj.close()
            break

        wait = 0.05
        if failure is None:
            wait = max(0, min(wait, deadline - now))
        elif terminate_at is not None:
            wait = max(0, min(wait, terminate_at - now))

        for key, _ in selector.select(wait):
            stream = key.fileobj
            try:
                chunk = os.read(stream.fileno(), 8192)
            except BlockingIOError:
                continue
            if not chunk:
                selector.unregister(stream)
                stream.close()
                continue

            buffer = output[stream]
            if failure is None:
                remaining = MAX_OUTPUT_BYTES - len(buffer)
                if len(chunk) > remaining:
                    if remaining > 0:
                        buffer.extend(chunk[:remaining])
                    failure = f"command {names[stream]} exceeded the 64 KiB output limit\n"
                    terminate_at = time.monotonic() + TERMINATE_GRACE_SECONDS
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                else:
                    buffer.extend(chunk)

    try:
        exit_code = process.wait(timeout=KILL_DRAIN_SECONDS)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        exit_code = process.wait()
    selector.close()
    if failure:
        os.write(2, failure.encode("ascii"))
        return 124 if "time limit" in failure else 125

    stdout = output[process.stdout]
    stderr = output[process.stderr]
    if stdout:
        os.write(1, stdout)
    if stderr:
        os.write(2, stderr)
    return exit_code if exit_code >= 0 else min(255, 128 - exit_code)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
