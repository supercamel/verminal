# Verminal

Verminal is a Gtk4 terminal application for serial, TCP, and UDP work. It sends and receives ASCII text or hexadecimal byte strings, with configurable line endings for transmitted payloads.

## Features

- Serial connections through `gserial`
- TCP client connections to a remote server
- UDP endpoint mode with configurable local listen port
- ASCII and HEX display/send modes
- Configurable `None`, `LF`, `CR`, and `CRLF` line endings
- Self-discoverable Gtk4 UI with tooltips on connection and payload controls
- Meson build and sqgipkg native-entry packaging

## Build

```sh
meson setup build
meson compile -C build
./build/verminal
```

Local builds expect `gserial-1.0` to be installed on the system. Packaged builds fetch, cross-build, and install `gserial` into the sqgipkg sysroot through `sqgipkg.json`.

## Package

```sh
sqgipkg --target appimage --appimage-arch x86_64
sqgipkg --target appimage --appimage-arch aarch64
sqgipkg --target win-nsis
```

The release workflow builds both Linux AppImages and the Windows installer on tag pushes matching `v*`.
