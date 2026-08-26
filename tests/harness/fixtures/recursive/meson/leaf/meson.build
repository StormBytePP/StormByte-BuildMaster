project('bm_rec_meson_leaf', 'c', version: '0.1.0', meson_version: '>=0.60.0')

# Align archive basename with library_import_static_hint / CMAKE_STATIC_*
# (Windows MSVC: leaflib.lib; Unix: libleaflib.a).
if host_machine.system() == 'windows'
	_name_prefix = ''
	_name_suffix = 'lib'
else
	_name_prefix = 'lib'
	_name_suffix = 'a'
endif

static_library(
	'leaflib',
	'leaf.c',
	install: true,
	install_dir: join_paths(get_option('libdir'), 'recursive', 'meson'),
	name_prefix: _name_prefix,
	name_suffix: _name_suffix,
)

install_headers(
	'leaf.h',
	subdir: 'recursive/meson',
)
