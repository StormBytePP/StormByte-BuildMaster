project('bm_grp_maudio', 'c', version: '0.1.0', meson_version: '>=0.60.0')

if host_machine.system() == 'windows'
    _name_prefix = ''
    _name_suffix = 'lib'
else
    _name_prefix = 'lib'
    _name_suffix = 'a'
endif

static_library(
    'grpmaudio',
    'maudio.c',
    install: true,
    install_dir: get_option('libdir'),
    name_prefix: _name_prefix,
    name_suffix: _name_suffix,
)

install_headers('grpmaudio.h')
