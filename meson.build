project(
  'verminal',
  'vala',
  'c',
  version: '0.1.0',
  license: 'MIT',
  default_options: [
    'warning_level=2',
    'werror=false'
  ]
)

gnome = import('gnome')
i18n = import('i18n')

gtk_dep = dependency('gtk4', version: '>= 4.10')
gio_dep = dependency('gio-2.0')
glib_dep = dependency('glib-2.0')
gserial_dep = dependency('gserial-1.0')

executable(
  'verminal',
  [
    'src/main.vala',
    'src/terminal_utils.vala',
    'src/transports.vala',
    'src/window.vala'
  ],
  dependencies: [
    gtk_dep,
    gio_dep,
    glib_dep,
    gserial_dep
  ],
  install: true
)

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
