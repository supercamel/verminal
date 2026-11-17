public int main (string[] args) {
    assert (args.length == 3);
    var config = new Verminal.ConnectionConfig ();
    config.host = "127.0.0.1";
    config.port = (uint16) int.parse (args[2]);
    Verminal.Transport transport;
    if (args[1] == "tcp") {
        config.kind = Verminal.ConnectionKind.TCP;
        transport = new Verminal.TcpTransport ();
    } else {
        assert (args[1] == "udp");
        config.kind = Verminal.ConnectionKind.UDP;
        transport = new Verminal.UdpTransport ();
    }

    var loop = new MainLoop ();
    uint8[] expected = {};
    int received = 0;
    transport.received.connect ((bytes) => {
        assert (MainContext.default ().is_owner ());
        assert (bytes.length > 0);
        assert (received + bytes.length <= expected.length);
        for (int i = 0; i < bytes.length; i++)
            assert (bytes[i] == expected[received + i]);
        received += bytes.length;
        if (received == expected.length) loop.quit ();
    });
    transport.failed.connect ((message) => error ("Receive failed: %s", message));

    string message;
    assert (transport.open (config, out message));
    foreach (int size in new int[] {5, 256, 2048, 5}) {
        expected = new uint8[size];
        if (size == 5) {
            expected = {80, 73, 78, 71, 10}; // PING followed by LF.
        } else {
            for (int i = 0; i < size; i++) expected[i] = (uint8) (i % 256);
        }
        received = 0;
        assert (transport.send (expected, out message));
        var timeout = Timeout.add_seconds (5, () => {
            error ("Timed out waiting for %s reply", args[1]);
        });
        // Let the reader queue and release its chunks before the UI dispatches them.
        Thread.usleep (100000);
        loop.run ();
        Source.remove (timeout);
        assert (received == expected.length);
    }
    transport.close ();
    stdout.printf ("%s text and binary replies preserved across delayed dispatch\n", args[1]);
    return 0;
}
