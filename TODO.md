# Verminal Implementation Checklist

- [x] Create a Vala project built with Meson.
- [x] Build the application with Gtk4.
- [x] Implement serial connections through `gserial`.
- [x] Implement TCP client connections with GLib/Gio.
- [x] Implement UDP endpoint send/receive with GLib/Gio.
- [x] Support sending ASCII payloads.
- [x] Support sending HEX byte strings.
- [x] Support receiving and displaying payloads as ASCII or HEX.
- [x] Add configurable transmit line endings: none, LF, CR, and CRLF.
- [x] Create a polished, intuitive UI with connection, payload, log, and send controls.
- [x] Add tooltips so the UI is self-discoverable.
- [x] Add desktop and AppStream metadata.
- [x] Add `sqgipkg.json` using the native-entry packaging mode.
- [x] Keep local Meson builds on the system-wide `gserial-1.0` package without a repo-local VAPI or Meson wrap.
- [x] Make sqgipkg fetch/build/install `gserial` using the RFDTool/Theia cross-build pattern.
- [x] Add GitHub Actions release CI using the RFDTool release workflow as the local reference.
- [x] Document build and packaging commands in `README.md`.
