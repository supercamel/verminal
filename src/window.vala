namespace Verminal {
    public class Window : Gtk.ApplicationWindow {
        private ConnectionConfig config = new ConnectionConfig ();
        private Transport? transport;

        private Gtk.DropDown kind_drop;
        private Gtk.Entry serial_entry;
        private Gtk.DropDown serial_drop;
        private Gtk.Button refresh_button;
        private Gtk.Label serial_hint;
        private GSerial.DeviceManager device_manager = new GSerial.DeviceManager ();
        private GSerial.Device[] serial_devices = {};
        private string? pending_permission;
        private Gtk.Stack pages;
        private Gtk.Box body;
        private Gtk.ScrolledWindow settings_scroll;
        private Gtk.ToggleButton settings_button;
        private Gtk.Label header_title;
        private Gtk.Widget serial_fields;
        private Gtk.Widget network_fields;
        private Gtk.Widget udp_fields;
        private bool compact = false;
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

            set_icon_name (Verminal.App.APP_ICON_NAME);
            build_ui ();
            install_css ();
            update_controls ();
            device_manager.permission_result.connect (permission_result);
            refresh_serial_ports ();
            set_focus (log_view);
            add_tick_callback (() => {
                update_layout (get_width ());
                return Source.CONTINUE;
            });
        }

        private void build_ui () {
            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            set_child (root);

            var header = new Gtk.HeaderBar ();
            header.show_title_buttons = true;
            header.decoration_layout = ":close";
            header_title = new Gtk.Label ("Verminal");
            header.title_widget = header_title;
            set_titlebar (header);

            settings_button = new Gtk.ToggleButton ();
            settings_button.icon_name = "emblem-system-symbolic";
            settings_button.tooltip_text = "Show connection and payload settings";
            settings_button.visible = false;
            settings_button.toggled.connect (() => {
                pages.visible_child_name = compact && settings_button.active ? "settings" : "terminal";
            });
            header.pack_start (settings_button);

            connect_button = new Gtk.Button.with_label ("Connect");
            connect_button.tooltip_text = "Open or close the selected connection";
            connect_button.add_css_class ("suggested-action");
            connect_button.clicked.connect (toggle_connection);
            header.pack_start (connect_button);

            var clear_button = new Gtk.Button.from_icon_name ("edit-clear-all-symbolic");
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
            status_label.ellipsize = Pango.EllipsizeMode.END;
            status_label.xalign = 0;
            status_label.hexpand = true;
            status_label.max_width_chars = 1;
            status_label.notify["label"].connect (() => status_label.tooltip_text = status_label.label);

            pages = new Gtk.Stack ();
            pages.hhomogeneous = false;
            pages.vhomogeneous = false;
            pages.hexpand = true;
            pages.vexpand = true;
            root.append (pages);

            body = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            pages.add_named (body, "terminal");

            var sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
            sidebar.add_css_class ("sidebar");
            settings_scroll = new Gtk.ScrolledWindow ();
            settings_scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            settings_scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
            settings_scroll.width_request = 290;
            settings_scroll.set_child (sidebar);
            body.append (settings_scroll);

            sidebar.append (section_title ("Connection"));

            kind_drop = new Gtk.DropDown.from_strings ({"Serial", "TCP", "UDP"});
            kind_drop.tooltip_text = "Choose serial, TCP client, or UDP endpoint mode";
            kind_drop.notify["selected"].connect (() => update_controls ());
            sidebar.append (labelled ("Mode", kind_drop));

            var serial_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            serial_fields = serial_box;
            sidebar.append (serial_box);
            var port_picker = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            serial_drop = new Gtk.DropDown.from_strings ({"Select a serial port"});
            serial_drop.hexpand = true;
            serial_drop.enable_search = true;
            serial_drop.tooltip_text = "Discovered serial ports and USB serial adapters";
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect ((object) => {
                var item = (Gtk.ListItem) object;
                var label = new Gtk.Label ("");
                label.xalign = 0;
                label.ellipsize = Pango.EllipsizeMode.MIDDLE;
                label.max_width_chars = 22;
                item.child = label;
            });
            factory.bind.connect ((object) => {
                var item = (Gtk.ListItem) object;
                var text = ((Gtk.StringObject) item.item).string;
                ((Gtk.Label) item.child).label = text;
                item.child.tooltip_text = text;
            });
            serial_drop.factory = factory;
            serial_drop.notify["selected"].connect (() => {
                var selected = serial_drop.selected;
                if (selected > 0 && selected <= serial_devices.length) {
                    var path = serial_devices[selected - 1].get_path ();
                    if (serial_entry.text != path) serial_entry.text = path;
                }
            });
            port_picker.append (serial_drop);
            refresh_button = new Gtk.Button.from_icon_name ("view-refresh-symbolic");
            refresh_button.tooltip_text = "Refresh serial ports after plugging or unplugging an adapter";
            refresh_button.clicked.connect (() => refresh_serial_ports ());
            port_picker.append (refresh_button);
            serial_box.append (labelled ("Serial Port", port_picker));

            serial_entry = new Gtk.Entry ();
            serial_entry.width_chars = 1;
            serial_entry.text = config.serial_path;
            serial_entry.placeholder_text = "/dev/ttyUSB0, COM3 or USB URI";
            serial_entry.tooltip_text = "Select a discovered port above or enter a device path manually";
            serial_entry.changed.connect (() => {
                uint selected = 0;
                for (uint i = 0; i < serial_devices.length; i++)
                    if (serial_devices[i].get_path () == serial_entry.text.strip ()) selected = i + 1;
                if (serial_drop.selected != selected) serial_drop.selected = selected;
            });
            serial_box.append (labelled ("Device Path", serial_entry));
            serial_hint = new Gtk.Label ("");
            serial_hint.wrap = true;
            serial_hint.xalign = 0;
            serial_hint.max_width_chars = 1;
            serial_hint.add_css_class ("dim-label");
            serial_box.append (serial_hint);

            baud_spin = new Gtk.SpinButton.with_range (300, 3000000, 100);
            baud_spin.value = config.serial_baud;
            baud_spin.tooltip_text = "Serial baud rate";
            serial_box.append (labelled ("Baud", baud_spin));

            var network_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            network_fields = network_box;
            sidebar.append (network_box);

            host_entry = new Gtk.Entry ();
            host_entry.width_chars = 1;
            host_entry.text = config.host;
            host_entry.tooltip_text = "TCP or UDP remote host";
            network_box.append (labelled ("Host", host_entry));

            port_spin = new Gtk.SpinButton.with_range (1, 65535, 1);
            port_spin.value = config.port;
            port_spin.tooltip_text = "TCP or UDP remote port";
            network_box.append (labelled ("Remote Port", port_spin));

            local_port_spin = new Gtk.SpinButton.with_range (0, 65535, 1);
            local_port_spin.value = config.local_port;
            local_port_spin.tooltip_text = "UDP local listen port; 0 lets the OS choose";
            udp_fields = labelled ("UDP Local Port", local_port_spin);
            network_box.append (udp_fields);

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
            log_view.tooltip_text = "Received and transmitted data";

            var scroller = new Gtk.ScrolledWindow ();
            scroller.hexpand = true;
            scroller.vexpand = true;
            scroller.set_child (log_view);
            main.append (scroller);

            var composer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            composer.add_css_class ("composer");
            main.append (composer);

            send_entry = new Gtk.Entry ();
            send_entry.width_chars = 1;
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
            root.append (status_label);
        }

        private void update_layout (int width) {
            bool narrow = width < 720;
            if (compact == narrow) return;
            compact = narrow;
            header_title.visible = !narrow;
            settings_button.visible = narrow;
            settings_button.active = false;
            if (narrow) {
                body.remove (settings_scroll);
                settings_scroll.width_request = -1;
                settings_scroll.hexpand = true;
                pages.add_named (settings_scroll, "settings");
            } else {
                pages.remove (settings_scroll);
                settings_scroll.width_request = 290;
                settings_scroll.hexpand = false;
                body.prepend (settings_scroll);
            }
            pages.visible_child_name = "terminal";
        }

        private void refresh_serial_ports () {
            var previous = serial_entry.text.strip ();
            try {
                var devices = device_manager.list_devices ();
                serial_devices = {};
                string[] labels = {"Select a port or enter a path"};
                uint selected = 0;
                foreach (var device in devices) {
                    serial_devices += device;
                    labels += "%s — %s".printf (device.get_name (), device.get_path ());
                    if (device.get_path () == previous) selected = serial_devices.length;
                }
                serial_drop.model = new Gtk.StringList (labels);
                serial_drop.selected = selected;
                serial_hint.label = serial_devices.length == 0
                    ? "No serial ports found. Attach an adapter and refresh, or enter a device path."
                    : "%u port(s) found. Select a port to connect.".printf (serial_devices.length);
            } catch (Error e) {
                serial_devices = {};
                serial_drop.model = new Gtk.StringList ({"Discovery unavailable"});
                serial_hint.label = "Could not list ports: " + e.message;
            }
            // Refresh must never replace a manually entered or detached device.
            serial_entry.text = previous;
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
                button, entry, dropdown, spinbutton {
                    min-height: 36px;
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

            bool editable = pending_permission == null && (transport == null || !transport.connected);
            kind_drop.sensitive = editable;
            serial_fields.visible = is_serial;
            network_fields.visible = !is_serial;
            udp_fields.visible = is_udp;
            serial_fields.sensitive = editable;
            network_fields.sensitive = editable;
            send_button.sensitive = transport != null && transport.connected;
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
            if (pending_permission != null) {
                device_manager.cancel_permission ();
                pending_permission = null;
                status_label.label = "Permission request cancelled";
                connect_button.label = "Connect";
                update_controls ();
                return;
            }
            if (transport != null && transport.connected) {
                close_transport ("Disconnected");
                return;
            }

            read_config ();
            if (config.kind == ConnectionKind.SERIAL) {
                if (config.serial_path == "") {
                    status_label.label = "Select a serial port or enter a device path";
                    if (compact) settings_button.active = true;
                    return;
                }
                if (config.serial_path.has_prefix ("usb://")) {
                    try {
                        var device = device_manager.lookup (config.serial_path);
                        if (device == null) throw new IOError.NOT_FOUND ("Serial adapter is no longer attached");
                        config.serial_path = device.get_path ();
                        serial_entry.text = config.serial_path;
                        if (!device.get_has_permission ()) {
                            pending_permission = config.serial_path;
                            if (!device_manager.request_permission (pending_permission))
                                throw new IOError.FAILED ("Could not request USB permission");
                            status_label.label = "Waiting for USB permission";
                            connect_button.label = "Cancel";
                            update_controls ();
                            return;
                        }
                    } catch (Error e) {
                        pending_permission = null;
                        status_label.label = "Error: " + e.message;
                        append_status (status_label.label);
                        update_controls ();
                        return;
                    }
                }
            }
            open_connection ();
        }

        private void permission_result (string path, bool granted, string message) {
            if (pending_permission == null || path != pending_permission) return;
            pending_permission = null;
            connect_button.label = "Connect";
            if (!granted) {
                status_label.label = message == "" ? "USB permission denied" : message;
                append_status (status_label.label);
                update_controls ();
                return;
            }
            try {
                var device = device_manager.lookup (path);
                if (device == null) throw new IOError.NOT_FOUND ("Serial adapter is no longer attached");
                config.serial_path = device.get_path ();
                serial_entry.text = config.serial_path;
                refresh_serial_ports ();
                open_connection ();
            } catch (Error e) {
                status_label.label = "Error: " + e.message;
                append_status (status_label.label);
                update_controls ();
            }
        }

        private void open_connection () {
            if (transport != null) transport.close ();
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
                update_controls ();
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
                update_controls ();
                return;
            }

            connect_button.label = "Disconnect";
            update_controls ();
            if (compact) settings_button.active = false;
        }

        private void close_transport (string status) {
            if (transport != null) {
                transport.close ();
                transport = null;
            }
            status_label.label = status;
            connect_button.label = "Connect";
            append_status (status);
            update_controls ();
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
            device_manager.cancel_permission ();
            pending_permission = null;
            close_transport ("Closed");
            return false;
        }
    }
}
