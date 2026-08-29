# LINKFLAGS: two contracts, BM-only here. Upstream trees live in os/ and unix/.
#
# lf-os    WINDOWS / LINUX / MAC — each injects bm_lf_ok (undefined at link
#          if the host group is dropped). No UNIX in this string.
# lf-unix  UNIX only — -Wl,-rpath,/bm-harness-unix (GNU ld and ld64).
#          Windows must drop the group. The unix exe is UNIX-only.

set(_os_src "${CMAKE_CURRENT_SOURCE_DIR}/os")
set(_os_build "${CMAKE_CURRENT_BINARY_DIR}/os_build")
set(_unix_src "${CMAKE_CURRENT_SOURCE_DIR}/unix")
set(_unix_build "${CMAKE_CURRENT_BINARY_DIR}/unix_build")
file(MAKE_DIRECTORY "${_os_build}" "${_unix_build}")

create_cmake_component(
	lf-os
	"Harness LINKFLAGS OS library"
	"${_os_src}"
	"${_os_build}"
	""
	static
	"lfos"
	"LINKFLAGS={WINDOWS={/ALTERNATENAME:bm_lf_ok=__ImageBase};LINUX={-Wl,--defsym,bm_lf_ok=1};MAC={-Wl,-alias,__mh_execute_header,_bm_lf_ok}}"
)

create_cmake_component(
	lf-unix
	"Harness LINKFLAGS UNIX library"
	"${_unix_src}"
	"${_unix_build}"
	""
	static
	"lfunix"
	"LINKFLAGS={UNIX={-Wl,-rpath,/bm-harness-unix}}"
)

create_meta_component(
	lf-os-meta
	"Harness LINKFLAGS OS meta"
	"LINKFLAGS={WINDOWS={/ALTERNATENAME:bm_lf_ok=__ImageBase};LINUX={-Wl,--defsym,bm_lf_ok=1};MAC={-Wl,-alias,__mh_execute_header,_bm_lf_ok}}"
)
create_meta_component(
	lf-unix-meta
	"Harness LINKFLAGS UNIX meta"
	"LINKFLAGS={UNIX={-Wl,-rpath,/bm-harness-unix}}"
)
meta_component_add(lf-os-meta lf-os)
meta_component_add(lf-unix-meta lf-unix)

add_executable(linkflags_os_test linkflags_os_test.c)
target_link_libraries(linkflags_os_test PRIVATE lf-os)
add_dependencies(linkflags_os_test lf-os_install)

add_custom_target(linkflags_os_test_run
	COMMAND $<TARGET_FILE:linkflags_os_test>
	DEPENDS linkflags_os_test
	COMMENT "[BuildMaster/Core     ]: run linkflags_os_test (WINDOWS/LINUX/MAC fire; expect 0)"
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
		COMMENT "[BuildMaster/Core     ]: run linkflags_unix_test (UNIX rpath accepted; expect 0)"
	)
endif()
