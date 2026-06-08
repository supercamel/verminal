namespace Verminal {
    public class Window : Gtk.ApplicationWindow {
        private ConnectionConfig config = new ConnectionConfig ();
        private Transport? transport;

        private Gtk.DropDown kind_drop;
        private Gtk.Entry serial_entry;
        private Gtk.SpinButton baud_spin;
        private Gtk.Entry host_entry;
        private Gtk.SpinButton port_spin;
        private Gtk.SpinButton local_port_spin;
        private Gtk.ToggleButton ascii_button;
        private Gtk.ToggleButton hex_button;
        private Gtk.DropDown ending_drop;
        private Gtk.TextView log_view;
        private Gtk.TextBuffer log_buffer;
        private Gtk.Entry send_entry;
        private Gtk.Button connect_button;
        private Gtk.Button send_button;
        private Gtk.Label status_label;
        private Gtk.Label rx_count_label;
        private Gtk.Label tx_count_label;

        private PayloadFormat format = PayloadFormat.ASCII;
        private uint64 rx_count = 0;
        private uint64 tx_count = 0;

        public Window (Gtk.Application app) {
            Object (
                application: app,
                title: "Verminal",
                default_width: 1060,
                default_height: 720
            );

            build_ui ();
            install_css ();
            update_controls ();
        }

        private void build_ui () {
            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            set_child (root);

            var header = new Gtk.HeaderBar ();
            header.show_title_buttons = true;
            set_titlebar (header);

            connect_button = new Gtk.Button.with_label ("Connect");
            connect_button.tooltip_text = "Open or close the selected connection";
            connect_button.add_css_class ("suggested-action");
            connect_button.clicked.connect (toggle_connection);
            header.pack_start (connect_button);

            var clear_button = new Gtk.Button.with_label ("Clear");
            clear_button.tooltip_text = "Clear the receive/transmit log";
            clear_button.clicked.connect (() => {
                log_buffer.text = "";
                rx_count = 0;
                tx_count = 0;
                update_counts ();
            });
            header.pack_end (clear_button);

            status_label = new Gtk.Label ("Disconnected");
            status_label.add_css_class ("status-pill");
            header.pack_end (status_label);

            var body = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            root.append (body);

            var sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
            sidebar.add_css_class ("sidebar");
            sidebar.width_request = 320;
            body.append (sidebar);

            sidebar.append (section_title ("Connection"));

            kind_drop = new Gtk.DropDown.from_strings ({"Serial", "TCP", "UDP"});
            kind_drop.tooltip_text = "Choose serial, TCP client, or UDP endpoint mode";
            kind_drop.notify["selected"].connect (() => update_controls ());
            sidebar.append (labelled ("Mode", kind_drop));

            serial_entry = new Gtk.Entry ();
            serial_entry.text = config.serial_path;
            serial_entry.tooltip_text = "Serial device path such as /dev/ttyUSB0 or COM3";
            sidebar.append (labelled ("Serial Port", serial_entry));

            baud_spin = new Gtk.SpinButton.with_range (300, 3000000, 100);
            baud_spin.value = config.serial_baud;
            baud_spin.tooltip_text = "Serial baud rate";
            sidebar.append (labelled ("Baud", baud_spin));

            host_entry = new Gtk.Entry ();
            host_entry.text = config.host;
            host_entry.tooltip_text = "TCP or UDP remote host";
            sidebar.append (labelled ("Host", host_entry));

            port_spin = new Gtk.SpinButton.with_range (1, 65535, 1);
            port_spin.value = config.port;
            port_spin.tooltip_text = "TCP or UDP remote port";
            sidebar.append (labelled ("Remote Port", port_spin));

            local_port_spin = new Gtk.SpinButton.with_range (0, 65535, 1);
            local_port_spin.value = config.local_port;
            local_port_spin.tooltip_text = "UDP local listen port; 0 lets the OS choose";
            sidebar.append (labelled ("UDP Local Port", local_port_spin));

            sidebar.append (section_title ("Payload"));

            var format_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            format_box.add_css_class ("linked");
            ascii_button = new Gtk.ToggleButton.with_label ("ASCII");
            ascii_button.tooltip_text = "Send and display text payloads";
            ascii_button.active = true;
            hex_button = new Gtk.ToggleButton.with_label ("HEX");
            hex_button.tooltip_text = "Send and display bytes as hexadecimal pairs";
            ascii_button.clicked.connect (() => set_format (PayloadFormat.ASCII));
            hex_button.clicked.connect (() => set_format (PayloadFormat.HEX));
            format_box.append (ascii_button);
            format_box.append (hex_button);
            sidebar.append (labelled ("Format", format_box));

            ending_drop = new Gtk.DropDown.from_strings ({"None", "LF", "CR", "CRLF"});
            ending_drop.selected = 1;
            ending_drop.tooltip_text = "Line ending appended when sending";
            sidebar.append (labelled ("Line Ending", ending_drop));

            rx_count_label = new Gtk.Label ("RX 0 B");
            tx_count_label = new Gtk.Label ("TX 0 B");
            var stats = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            rx_count_label.add_css_class ("counter");
            tx_count_label.add_css_class ("counter");
            stats.append (rx_count_label);
            stats.append (tx_count_label);
            sidebar.append (stats);

            var main = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            main.hexpand = true;
            main.vexpand = true;
            body.append (main);

            log_buffer = new Gtk.TextBuffer (null);
            log_view = new Gtk.TextView.with_buffer (log_buffer);
            log_view.editable = false;
            log_view.monospace = true;
            log_view.wrap_mode = Gtk.WrapMode.CHAR;
            log_view.add_css_class ("terminal-log");

            var scroller = new Gtk.ScrolledWindow ();
            scroller.hexpand = true;
            scroller.vexpand = true;
            scroller.set_child (log_view);
            main.append (scroller);

            var composer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            composer.add_css_class ("composer");
            main.append (composer);

            send_entry = new Gtk.Entry ();
            send_entry.hexpand = true;
            send_entry.placeholder_text = "Type bytes to send";
            send_entry.tooltip_text = "Enter ASCII text or HEX byte pairs, depending on the selected format";
            send_entry.activate.connect (send_payload);
            composer.append (send_entry);

            send_button = new Gtk.Button.with_label ("Send");
            send_button.tooltip_text = "Transmit the current payload";
            send_button.add_css_class ("suggested-action");
            send_button.clicked.connect (send_payload);
            composer.append (send_button);
        }

        private Gtk.Widget section_title (string text) {
            var label = new Gtk.Label (text);
            label.xalign = 0;
            label.add_css_class ("section-title");
            return label;
        }

        private Gtk.Widget labelled (string label_text, Gtk.Widget control) {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            var label = new Gtk.Label (label_text);
            label.xalign = 0;
            label.add_css_class ("dim-label");
            box.append (label);
            box.append (control);
            return box;
        }

        private void install_css () {
            var css = new Gtk.CssProvider ();
            css.load_from_data ("""
                window {
                    background: #f6f7f4;
                    color: #1e211f;
                }
                .sidebar {
                    padding: 18px;
                    background: #eef1ec;
                    border-right: 1px solid #d5dbd2;
                }
                .section-title {
                    font-weight: 700;
                    font-size: 1.05em;
                }
                .dim-label {
                    color: #5e665d;
                    font-size: 0.86em;
                    font-weight: 600;
                }
                .terminal-log {
                    background: #171a18;
                    color: #d8ead6;
                    padding: 14px;
                }
                .composer {
                    padding: 10px;
                    background: #ffffff;
                    border-top: 1px solid #d5dbd2;
                }
                .counter, .status-pill {
                    padding: 5px 9px;
                    border-radius: 6px;
                    background: #dfe7dd;
                    color: #243026;
                    font-weight: 600;
                }
            """.data);

            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                css,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }

        private void set_format (PayloadFormat selected) {
            format = selected;
            ascii_button.active = selected == PayloadFormat.ASCII;
            hex_button.active = selected == PayloadFormat.HEX;
            send_entry.placeholder_text = selected == PayloadFormat.ASCII
                ? "Type text to send"
                : "Type HEX bytes, e.g. 48 65 6C 6C 6F";
        }

        private void update_controls () {
            var kind = (ConnectionKind) kind_drop.selected;
            var is_serial = kind == ConnectionKind.SERIAL;
            var is_udp = kind == ConnectionKind.UDP;

            serial_entry.sensitive = is_serial;
            baud_spin.sensitive = is_serial;
            host_entry.sensitive = !is_serial;
            port_spin.sensitive = !is_serial;
            local_port_spin.sensitive = is_udp;
        }

        private void read_config () {
            config.kind = (ConnectionKind) kind_drop.selected;
            config.serial_path = serial_entry.text.strip ();
            config.serial_baud = (uint) baud_spin.get_value_as_int ();
            config.host = host_entry.text.strip ();
            config.port = (uint16) port_spin.get_value_as_int ();
            config.local_port = (uint16) local_port_spin.get_value_as_int ();
        }

        private void toggle_connection () {
            if (transport != null && transport.connected) {
                close_transport ("Disconnected");
                return;
            }

            read_config ();
            switch (config.kind) {
                case ConnectionKind.SERIAL:
                    transport = new SerialTransport ();
                    break;
                case ConnectionKind.TCP:
                    transport = new TcpTransport ();
                    break;
                case ConnectionKind.UDP:
                    transport = new UdpTransport ();
                    break;
            }

            transport.received.connect ((bytes) => {
                rx_count += bytes.length;
                append_log ("RX", bytes);
                update_counts ();
            });
            transport.state.connect ((text) => {
                status_label.label = text;
                append_status (text);
                connect_button.label = transport != null && transport.connected ? "Disconnect" : "Connect";
            });
            transport.failed.connect ((text) => {
                append_status ("Error: " + text);
                status_label.label = "Error";
            });

            string error;
            if (!transport.open (config, out error)) {
                append_status ("Error: " + error);
                status_label.label = "Error";
                transport = null;
                connect_button.label = "Connect";
                return;
            }

            connect_button.label = "Disconnect";
        }

        private void close_transport (string status) {
            if (transport != null) {
                transport.close ();
                transport = null;
            }
            status_label.label = status;
            connect_button.label = "Connect";
            append_status (status);
        }

        private LineEnding selected_ending () {
            return (LineEnding) ending_drop.selected;
        }

        private void send_payload () {
            if (transport == null || !transport.connected) {
                append_status ("Connect before sending");
                return;
            }

            uint8[] bytes;
            string error;
            if (!parse_payload (send_entry.text, format, selected_ending (), out bytes, out error)) {
                append_status ("Error: " + error);
                return;
            }

            if (bytes.length == 0) {
                append_status ("Nothing to send");
                return;
            }

            if (!transport.send (bytes, out error)) {
                append_status ("Error: " + error);
                return;
            }

            tx_count += bytes.length;
            append_log ("TX", bytes);
            update_counts ();
            send_entry.text = "";
        }

        private void append_status (string text) {
            Gtk.TextIter end;
            log_buffer.get_end_iter (out end);
            log_buffer.insert (ref end, "[%s] -- %s\n".printf (stamp_now (), text), -1);
            scroll_to_end ();
        }

        private void append_log (string direction, uint8[] bytes) {
            Gtk.TextIter end;
            log_buffer.get_end_iter (out end);
            var rendered = format_bytes (bytes, format);
            log_buffer.insert (ref end, "[%s] %s  %s\n".printf (stamp_now (), direction, rendered), -1);
            scroll_to_end ();
        }

        private void scroll_to_end () {
            Gtk.TextIter end;
            log_buffer.get_end_iter (out end);
            log_view.scroll_to_iter (end, 0.0, false, 0.0, 1.0);
        }

        private void update_counts () {
            rx_count_label.label = "RX %llu B".printf (rx_count);
            tx_count_label.label = "TX %llu B".printf (tx_count);
        }

        protected override bool close_request () {
            close_transport ("Closed");
            return false;
        }
    }
}
