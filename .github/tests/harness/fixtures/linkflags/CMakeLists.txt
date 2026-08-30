# LINKFLAGS: two contracts, BM-only here. Upstream trees live in os/ and unix/.
#
# lf-os    WINDOWS / LINUX / MAC — folded into that id's nested OPTIONS.
#          No UNIX in this string. Not INTERFACE.
# lf-unix  UNIX only — -Wl,-rpath,/bm-harness-unix (GNU ld and ld64).
#          Windows must drop the group.
# Metas declare the same LINKFLAGS on purpose: ignored (WARNING). The
# check asserts they do not appear on the meta INTERFACE or OPTIONS.

set(_os_src "${CMAKE_CURRENT_SOURCE_DIR}/os")
set(_unix_src "${CMAKE_CURRENT_SOURCE_DIR}/unix")

_bm_backend_cmake_create(
	lf-os
	"Harness LINKFLAGS OS library"
	"${_os_src}"
	""
	static
	"lfos"
	"LINKFLAGS={WINDOWS={/ALTERNATENAME:bm_lf_ok=__ImageBase};LINUX={-Wl,--defsym,bm_lf_ok=1};MAC={-Wl,-alias,__mh_execute_header,_bm_lf_ok}}"
)

_bm_backend_cmake_create(
	lf-unix
	"Harness LINKFLAGS UNIX library"
	"${_unix_src}"
	""
	static
	"lfunix"
	"LINKFLAGS={UNIX={-Wl,-rpath,/bm-harness-unix}}"
)

buildmaster_meta(
	lf-os-meta
	"Harness LINKFLAGS OS meta"
	"LINKFLAGS={WINDOWS={/ALTERNATENAME:bm_lf_ok=__ImageBase};LINUX={-Wl,--defsym,bm_lf_ok=1};MAC={-Wl,-alias,__mh_execute_header,_bm_lf_ok}}"
)
buildmaster_meta(
	lf-unix-meta
	"Harness LINKFLAGS UNIX meta"
	"LINKFLAGS={UNIX={-Wl,-rpath,/bm-harness-unix}}"
)
buildmaster_meta_add(lf-os-meta lf-os)
buildmaster_meta_add(lf-unix-meta lf-unix)

# Host binaries consume the archive only. They must link without inheriting
# LINKFLAGS (that is the leak this contract forbids).
add_executable(linkflags_os_test linkflags_os_test.c)
target_include_directories(linkflags_os_test PRIVATE
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
target_link_libraries(linkflags_os_test PRIVATE lf-os)
add_dependencies(linkflags_os_test lf-os_install)

add_custom_target(linkflags_os_test_run
	COMMAND $<TARGET_FILE:linkflags_os_test>
	DEPENDS linkflags_os_test
	COMMENT "[BuildMaster/Core     ]: run linkflags_os_test (archive usable without inherited LINKFLAGS)"
)

if(NOT WIN32)
	add_executable(linkflags_unix_test linkflags_unix_test.c)
	target_include_directories(linkflags_unix_test PRIVATE
		"${BUILDMASTER_INSTALL_INCLUDEDIR}"
	)
	target_link_libraries(linkflags_unix_test PRIVATE lf-unix)
	add_dependencies(linkflags_unix_test lf-unix_install)

	add_custom_target(linkflags_unix_test_run
		COMMAND $<TARGET_FILE:linkflags_unix_test>
		DEPENDS linkflags_unix_test
		COMMENT "[BuildMaster/Core     ]: run linkflags_unix_test (archive usable without inherited LINKFLAGS)"
	)
endif()
