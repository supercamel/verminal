# Verminal

Verminal is a Gtk4 terminal application for serial, TCP, and UDP work. It sends and receives ASCII text or hexadecimal byte strings, with configurable line endings for transmitted payloads.

## Features

- Serial connections through Ooblerg's `gserial`, with discovered port names and paths, refresh, and manual path entry
- TCP client connections to a remote server
- UDP endpoint mode with configurable local listen port
- ASCII and HEX display/send modes
- Configurable `None`, `LF`, `CR`, and `CRLF` line endings
- Self-discoverable Gtk4 UI with tooltips on connection and payload controls
- Android USB OTG serial adapters with the system's per-device permission prompt
- Phone, tablet, and desktop layouts: below 720 logical pixels, the settings button switches between settings and the terminal; wider windows show both

## Build and package

Install a current `sqgipkg` with Android `noble-android-r7` support, Meson, Vala,
the platform cross compilers, and NSIS. The manifest uses Ooblerg's `gserial`
packages on Linux and Windows and `extras-gserial` on Android. Desktop packages
must contain the device discovery API from the `v1.1.0` release; the old
`v1.0.0` package cannot build this version. GTK and its dependencies are resolved
by `sqgipkg` into private build environments.

```sh
sqgipkg setup --platform android --native-tools --accept-licenses
sqgipkg check --target all
sqgipkg build --target all --write-lock
```

The manifest builds Linux x86_64 and aarch64 AppImages, a Windows x86_64
installer, and Android arm64-v8a and x86_64 APKs. Android requires Android 12
(API 31) or newer. `sqgipkg` does not currently target macOS or iOS.

Individual targets:

```sh
sqgipkg build --platform linux --arch x86_64
sqgipkg build --platform linux --arch aarch64
sqgipkg build --platform windows
sqgipkg build --platform android --arch arm64-v8a
sqgipkg build --platform android --arch x86_64
```

Outputs are under `dist-linux-x86_64/`, `dist-linux-aarch64/`,
`dist-windows-x86_64/`, `dist-android-arm64-v8a/`, and `dist-android-x86_64/`.
Individual Android builds use `dist-android/`. APKs use debug signing for local
installation. Store distribution needs release signing. `sqgipkg.lock.json`
is a generated build receipt (also copied into release artifacts) that records
resolved package checksums; use `--locked` to replay those inputs with
the recorded toolchain. The release workflow builds all targets and attaches
them to `v*` releases.

## Run on Android

Build the ARM64 APK for most phones and tablets, or use the x86_64 APK with
SQGI's emulator. To prepare the emulator and run a local x86_64 build:

```sh
sqgipkg setup --platform android --emulator --native-tools --accept-licenses
sqgipkg emulator --headless
sqgipkg deploy --platform android --arch x86_64 --serial emulator-5564
sqgipkg logs --platform android --arch x86_64 --serial emulator-5564 --logs-once
```

To install an APK already produced by the full build without rebuilding it:

```sh
sqgipkg install --platform android --arch x86_64 --serial emulator-5564 \
  --artifact dist-android-x86_64/io.github.supercamel.Verminal-x86_64-debug.apk
sqgipkg run --platform android --arch x86_64 --serial emulator-5564
```

Replace the emulator serial and ABI with those of your connected device when
deploying to a phone or tablet. In compact windows, the gear button opens the
scrollable connection and payload settings; tap it again to return to the log.

## Serial ports

Choose a discovered port, set its baud, and connect. Refresh after attaching or
removing an adapter. Refresh preserves the selected or manually entered path;
it never silently selects a different device. An unavailable port produces an
error when connecting. Desktop paths such as `/dev/ttyUSB0`, `/dev/pts/3`, or
`COM3` can also be entered directly.

On Android, attach a supported USB serial adapter through USB OTG, refresh,
select it, and tap Connect. Grant the system permission prompt; Cancel stops
waiting for permission. After a grant, Verminal resolves the adapter's refreshed
identity before opening it. Re-enumerate after unplugging an adapter whose path
uses a temporary device ID. USB access does not require root. Actual adapter
transfers require a phone or tablet with USB host support; the emulator can
exercise the UI and network transports but has no USB serial hardware.

## Development checks

For local Meson builds, install GTK 4.10+ and a GSerial development package with
the discovery API. The GTK integration test checks phone, landscape, tablet, and
desktop sizes, port selection and refresh, failed opens, and serial traffic over
a pseudo-terminal. It writes layout screenshots into the build directory.

```sh
meson setup build-dev -Dtests=true
meson compile -C build-dev
xvfb-run -a meson test -C build-dev --print-errorlogs
./build-dev/verminal
```

Each packaged target writes a `sqgipkg-build.json` receipt beside its output.
Local validation artifacts, when collected, are under `artifacts/`: packages,
SHA-256 checksums, a build report, test output, and screenshots. These generated
files are excluded from Git.
