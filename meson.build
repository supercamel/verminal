project(
  'verminal',
  'vala',
  'c',
  version: '0.3.0',
  license: 'MIT',
  default_options: [
    'warning_level=2',
    'werror=false'
  ]
)

gtk_dep = dependency('gtk4', version: '>= 4.10')
gio_dep = dependency('gio-2.0')
glib_dep = dependency('glib-2.0')
gserial_dep = dependency('gserial-1.0')

sources = files(
    'src/main.vala',
    'src/terminal_utils.vala',
    'src/transports.vala',
    'src/window.vala'
)
deps = [
    gtk_dep,
    gio_dep,
    glib_dep,
    gserial_dep
]

# The package version historically reports 1.0, even for older APIs.
if not meson.get_compiler('c').has_function('gserial_device_manager_new',
    prefix: '#include <GSerial-1.0.h>', dependencies: gserial_dep)
  error('GSerial with device discovery is required (upstream 0.3.0 or newer). Update the Ooblerg gserial package.')
endif

if host_machine.system() == 'android'
  shared_library('verminal', sources + files('src/android-entry.c'),
    vala_args: ['--define=ANDROID'], dependencies: deps, install: true)
else
  executable('verminal', sources, dependencies: deps, install: true)
endif

if get_option('tests') and host_machine.system() == 'linux'
  network_test = executable('test-network',
    files('src/terminal_utils.vala', 'src/transports.vala', 'tests/network.vala'),
    dependencies: [gio_dep, glib_dep, gserial_dep])
  foreach protocol : ['tcp', 'udp']
    test(protocol + '-receive', find_program('python3'),
      args: [files('tests/run-network.py'), network_test, protocol], timeout: 30)
  endforeach

  ui_test = executable('test-ui', sources + files('tests/ui.vala'),
    vala_args: ['--define=TESTING'], dependencies: deps)
  test('responsive-ui', find_program('python3'),
    args: [files('tests/run-ui.py'), ui_test], timeout: 30,
    env: ['GSK_RENDERER=cairo', 'GTK_A11Y=none'])
endif

install_data(
  'data/io.github.supercamel.Verminal.desktop',
  install_dir: get_option('datadir') / 'applications'
)

install_data(
  'data/io.github.supercamel.Verminal.metainfo.xml',
  install_dir: get_option('datadir') / 'metainfo'
)

install_data(
  'images/io.github.supercamel.Verminal.png',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / '256x256' / 'apps'
)
