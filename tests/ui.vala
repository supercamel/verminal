private Gtk.Widget? find_widget (Gtk.Widget root, string tooltip) {
    if (root.tooltip_text == tooltip) return root;
    for (var child = root.get_first_child (); child != null; child = child.get_next_sibling ()) {
        var match = find_widget (child, tooltip);
        if (match != null) return match;
    }
    return null;
}

private void settle () {
    var loop = new MainLoop ();
    Timeout.add (150, () => { loop.quit (); return Source.REMOVE; });
    loop.run ();
}

private void capture (Gtk.Window win, string name) {
    var paintable = new Gtk.WidgetPaintable (win);
    var snapshot = new Gtk.Snapshot ();
    paintable.snapshot (snapshot, win.get_width (), win.get_height ());
    var node = snapshot.free_to_node ();
    assert (node != null);
    var renderer = Gsk.Renderer.for_surface (win.get_surface ());
    var texture = renderer.render_texture (node, null);
    assert (texture.save_to_png (name));
    renderer.unrealize ();
}

public int main (string[] args) {
    Gtk.init ();
    var app = new Verminal.App ();
    app.flags = ApplicationFlags.NON_UNIQUE;
    try { app.register (); } catch (Error e) { error ("%s", e.message); }
    var win = new Verminal.Window (app);
    win.present ();
    settle ();
    var settings = (Gtk.ToggleButton) find_widget (win, "Show connection and payload settings");
    var entry = (Gtk.Entry) find_widget (win, "Select a discovered port above or enter a device path manually");
    var refresh = (Gtk.Button) find_widget (win, "Refresh serial ports after plugging or unplugging an adapter");
    var ports = (Gtk.DropDown) find_widget (win, "Discovered serial ports and USB serial adapters");
    var mode = (Gtk.DropDown) find_widget (win, "Choose serial, TCP client, or UDP endpoint mode");
    var send = find_widget (win, "Transmit the current payload");
    assert (settings != null && entry != null && refresh != null && mode != null && send != null);

    int[,] sizes = {{360, 640}, {320, 480}, {800, 360}, {768, 1024}, {1280, 800}, {360, 640}};
    for (int i = 0; i < sizes.length[0]; i++) {
        int width = sizes[i, 0], height = sizes[i, 1];
        win.set_default_size (width, height);
        settle ();
        // Retry the requested size after the desktop sidebar has collapsed.
        win.set_default_size (width, height);
        settle ();
        stdout.printf ("Layout %dx%d: allocated %dx%d\n", width, height, win.get_width (), win.get_height ());
        assert (win.get_width () <= width);
        assert (win.get_height () <= height);
        assert (settings.visible == (width < 720));
        assert (send.get_mapped ());
        assert (send.get_allocated_width () >= 44);
        assert (send.get_allocated_height () >= 44);
        capture (win, "ui-%dx%d.png".printf (width, height));
        if (width < 720) {
            settings.active = true;
            settle ();
            assert (entry.get_mapped ());
            assert (!send.get_mapped ());
            assert (entry.get_width () > 100);
            capture (win, "ui-settings-%dx%d.png".printf (width, height));
            mode.selected = 1;
            settle ();
            assert (!entry.get_mapped ());
            mode.selected = 0;
            settle ();
            assert (entry.get_mapped ());
            settings.active = false;
            settle ();
            assert (send.get_mapped ());
        } else {
            assert (entry.get_mapped ());
        }
    }
    settings.active = true;
    if (ports.model.get_n_items () > 1) {
        ports.selected = 1;
        assert (entry.text != "");
        var selected_path = entry.text;
        refresh.clicked ();
        assert (entry.text == selected_path);
        assert (ports.selected > 0);
    }
    entry.text = "/dev/verminal-manual-test";
    refresh.clicked ();
    assert (entry.text == "/dev/verminal-manual-test");
    var connect = (Gtk.Button) find_widget (win, "Open or close the selected connection");
    connect.clicked ();
    assert (connect.label == "Connect");
    assert (!send.sensitive);

    var pty = Environment.get_variable ("VERMINAL_TEST_PTY");
    assert (pty != null);
    entry.text = pty;
    connect.clicked ();
    settle ();
    assert (connect.label == "Disconnect");
    assert (send.sensitive && send.get_mapped ());
    var payload = (Gtk.Entry) find_widget (win, "Enter ASCII text or HEX byte pairs, depending on the selected format");
    payload.text = "Verminal serial integration";
    ((Gtk.Button) send).clicked ();
    settle ();
    assert (payload.text == "");
    var log = (Gtk.TextView) find_widget (win, "Received and transmitted data");
    assert (log.buffer.text.contains ("TX  Verminal serial integration"));
    assert (log.buffer.text.contains ("RX  Verminal serial integration"));
    assert (!entry.sensitive || !entry.is_sensitive ());
    connect.clicked ();
    assert (connect.label == "Connect");
    assert (!send.sensitive);
    win.close ();
    stdout.printf ("Responsive UI, port selection, refresh, failed open, and serial send passed\n");
    return 0;
}
