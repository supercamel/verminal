namespace Verminal {
    public class ConnectionConfig : Object {
        public ConnectionKind kind { get; set; default = ConnectionKind.SERIAL; }
        public string serial_path { get; set; default = "/dev/ttyUSB0"; }
        public uint serial_baud { get; set; default = 115200; }
        public string host { get; set; default = "127.0.0.1"; }
        public uint16 port { get; set; default = 23; }
        public uint16 local_port { get; set; default = 0; }
    }

    public abstract class Transport : Object {
        public signal void received (uint8[] bytes);
        public signal void state (string text);
        public signal void failed (string text);
        public bool connected { get; protected set; default = false; }

        public abstract bool open (ConnectionConfig config, out string error);
        public abstract bool send (uint8[] bytes, out string error);
        public abstract void close ();

        protected void emit_received_main (uint8[] bytes) {
            Idle.add (() => {
                received (bytes);
                return Source.REMOVE;
            });
        }

        protected void emit_state_main (string text) {
            Idle.add (() => {
                state (text);
                return Source.REMOVE;
            });
        }

        protected void emit_failed_main (string text) {
            Idle.add (() => {
                failed (text);
                return Source.REMOVE;
            });
        }
    }

    public class SerialTransport : Transport {
        private GSerial.Port? port;
        private uint poll_id = 0;

        public override bool open (ConnectionConfig config, out string error) {
            close ();

            port = new GSerial.Port ();
            port.set_baud (config.serial_baud);
            port.set_timeout (20);

            if (!port.open (config.serial_path)) {
                error = "Could not open %s".printf (config.serial_path);
                port = null;
                return false;
            }

            connected = true;
            state ("Serial connected to %s @ %u".printf (config.serial_path, config.serial_baud));
            poll_id = Timeout.add (20, poll);
            error = "";
            return true;
        }

        private bool poll () {
            if (port == null || !port.is_open ()) {
                connected = false;
                poll_id = 0;
                state ("Serial disconnected");
                return Source.REMOVE;
            }

            var available = port.bytes_available ();
            if (available > 0) {
                var bytes = port.read_bytes (available);
                if (bytes.length > 0) {
                    received (bytes);
                }
            }

            return Source.CONTINUE;
        }

        public override bool send (uint8[] bytes, out string error) {
            if (port == null || !port.is_open ()) {
                error = "Serial port is not connected";
                return false;
            }

            var written = port.write_bytes (bytes);
            if (written != bytes.length) {
                error = "Serial write was short";
                return false;
            }

            error = "";
            return true;
        }

        public override void close () {
            if (poll_id != 0) {
                Source.remove (poll_id);
                poll_id = 0;
            }

            if (port != null && port.is_open ()) {
                port.close ();
            }

            port = null;
            connected = false;
        }
    }

    public class TcpTransport : Transport {
        private SocketConnection? connection;
        private Thread<void*>? reader;
        private bool closing = false;

        public override bool open (ConnectionConfig config, out string error) {
            close ();

            try {
                var client = new SocketClient ();
                connection = client.connect_to_host ("%s:%u".printf (config.host, config.port), config.port);
                closing = false;
                connected = true;
                state ("TCP connected to %s:%u".printf (config.host, config.port));
                reader = new Thread<void*> ("tcp-reader", read_loop);
                error = "";
                return true;
            } catch (Error e) {
                connection = null;
                connected = false;
                error = e.message;
                return false;
            }
        }

        private void* read_loop () {
            uint8[] buffer = new uint8[4096];
            while (!closing && connection != null) {
                try {
                    var count = connection.input_stream.read (buffer);
                    if (count <= 0) break;
                    uint8[] chunk = new uint8[count];
                    Memory.copy (chunk, buffer, count);
                    emit_received_main (chunk);
                } catch (Error e) {
                    if (!closing) emit_failed_main (e.message);
                    break;
                }
            }

            connected = false;
            emit_state_main ("TCP disconnected");
            return null;
        }

        public override bool send (uint8[] bytes, out string error) {
            if (connection == null || !connected) {
                error = "TCP is not connected";
                return false;
            }

            try {
                connection.output_stream.write_all (bytes, null);
                error = "";
                return true;
            } catch (Error e) {
                error = e.message;
                return false;
            }
        }

        public override void close () {
            closing = true;
            if (connection != null) {
                try {
                    connection.close ();
                } catch (Error e) {
                }
            }
            connection = null;
            connected = false;
        }
    }

    public class UdpTransport : Transport {
        private Socket? socket;
        private InetSocketAddress? remote;
        private Thread<void*>? reader;
        private bool closing = false;

        public override bool open (ConnectionConfig config, out string error) {
            close ();

            try {
                var resolver = Resolver.get_default ();
                var addresses = resolver.lookup_by_name (config.host);
                if (addresses.length () == 0) {
                    error = "Could not resolve %s".printf (config.host);
                    return false;
                }

                remote = new InetSocketAddress (addresses.nth_data (0), config.port);
                socket = new Socket (SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
                var local = new InetSocketAddress (new InetAddress.any (SocketFamily.IPV4), config.local_port);
                socket.bind (local, true);
                socket.connect (remote);

                closing = false;
                connected = true;
                state ("UDP ready for %s:%u".printf (config.host, config.port));
                reader = new Thread<void*> ("udp-reader", read_loop);
                error = "";
                return true;
            } catch (Error e) {
                socket = null;
                connected = false;
                error = e.message;
                return false;
            }
        }

        private void* read_loop () {
            uint8[] buffer = new uint8[4096];
            while (!closing && socket != null) {
                try {
                    var count = socket.receive (buffer);
                    if (count <= 0) continue;
                    uint8[] chunk = new uint8[count];
                    Memory.copy (chunk, buffer, count);
                    emit_received_main (chunk);
                } catch (Error e) {
                    if (!closing) emit_failed_main (e.message);
                    break;
                }
            }

            connected = false;
            emit_state_main ("UDP closed");
            return null;
        }

        public override bool send (uint8[] bytes, out string error) {
            if (socket == null || !connected) {
                error = "UDP is not connected";
                return false;
            }

            try {
                socket.send (bytes);
                error = "";
                return true;
            } catch (Error e) {
                error = e.message;
                return false;
            }
        }

        public override void close () {
            closing = true;
            if (socket != null) {
                try {
                    socket.close ();
                } catch (Error e) {
                }
            }
            socket = null;
            connected = false;
        }
    }
}
