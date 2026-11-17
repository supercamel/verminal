#!/usr/bin/env python3
"""Check real TCP/UDP round trips against a local echo server."""
import socket
import subprocess
import sys
import threading

binary, protocol = sys.argv[1:]
assert protocol in ("tcp", "udp")
payloads = [b"PING\n", bytes(range(256)), bytes(range(256)) * 8, b"PING\n"]
errors = []


def echo(server):
    try:
        if protocol == "tcp":
            connection, _ = server.accept()
            with connection:
                connection.settimeout(5)
                received = bytearray()
                while chunk := connection.recv(4096):
                    received.extend(chunk)
                    connection.sendall(chunk)
                assert received == b"".join(payloads), repr(received)
        else:
            for expected in payloads:
                chunk, address = server.recvfrom(4096)
                assert chunk == expected, repr(chunk)
                server.sendto(chunk, address)
    except Exception as error:
        errors.append(error)


kind = socket.SOCK_STREAM if protocol == "tcp" else socket.SOCK_DGRAM
with socket.socket(socket.AF_INET, kind) as server:
    server.bind(("127.0.0.1", 0))
    server.settimeout(5)
    if protocol == "tcp":
        server.listen(1)
    worker = threading.Thread(target=echo, args=(server,), daemon=True)
    worker.start()
    result = subprocess.run(
        [binary, protocol, str(server.getsockname()[1])], timeout=15
    )
    worker.join(timeout=6)
    if result.returncode:
        sys.exit(result.returncode)
    assert not worker.is_alive(), "Echo server did not finish"
    if errors:
        raise errors[0]
print(f"{protocol.upper()} server verified every transmitted byte")
