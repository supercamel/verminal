#!/usr/bin/env python3
"""Exercise the real serial transport with a PTY; no adapter is required."""
import os
import pty
import select
import subprocess
import sys
import threading

master, slave = pty.openpty()
received = bytearray()
done = threading.Event()


def echo():
    while not done.is_set():
        ready, _, _ = select.select([master], [], [], 0.1)
        if ready:
            chunk = os.read(master, 4096)
            received.extend(chunk)
            os.write(master, chunk)


thread = threading.Thread(target=echo, daemon=True)
thread.start()
try:
    result = subprocess.run(
        [sys.argv[1]], env=dict(os.environ, VERMINAL_TEST_PTY=os.ttyname(slave))
    )
finally:
    done.set()
    thread.join()
    os.close(master)
    os.close(slave)
if result.returncode:
    sys.exit(result.returncode)
assert bytes(received) == b"Verminal serial integration\n", repr(received)
print("PTY received the exact payload and line ending")
