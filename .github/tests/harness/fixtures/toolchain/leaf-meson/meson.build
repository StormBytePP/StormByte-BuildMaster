project('bm_tc_leaf_meson', 'c', version: '0.1.0', meson_version: '>=0.60.0')

_fam = get_option('expect_family')
if _fam == 'clang-cl'
	add_project_arguments('-DHARNESS_EXPECT_FAMILY_CLANG_CL=1', language: 'c')
elif _fam == 'msvc'
	add_project_arguments('-DHARNESS_EXPECT_FAMILY_MSVC=1', language: 'c')
elif _fam == 'clang'
	add_project_arguments('-DHARNESS_EXPECT_FAMILY_CLANG=1', language: 'c')
elif _fam == 'gcc'
	add_project_arguments('-DHARNESS_EXPECT_FAMILY_GCC=1', language: 'c')
else
	error('toolchain leaf-meson: unknown expect_family=' + _fam)
endif

inc = include_directories('..')

if host_machine.system() == 'windows'
	_name_prefix = ''
	_name_suffix = 'lib'
else
	_name_prefix = 'lib'
	_name_suffix = 'a'
endif

static_library(
	'tcleafmeson',
	'tc_leaf_meson.c',
	include_directories: inc,
	install: true,
	install_dir: join_paths(get_option('libdir'), 'toolchain'),
	name_prefix: _name_prefix,
	name_suffix: _name_suffix,
)

install_headers(
	'tc_leaf_meson.h',
	subdir: 'toolchain',
)
