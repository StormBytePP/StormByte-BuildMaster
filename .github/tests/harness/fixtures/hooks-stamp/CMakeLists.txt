# Component hook → file the nested *configure* requires.
# Graph hook     → header the nested *compile* requires.
# Deferred on hook-a so both hooks run at parent finalize, before
# hooks-stamp_configure.

set(HOOK_STAMP_INCLUDE "${CMAKE_CURRENT_BINARY_DIR}/hook_inc")
file(MAKE_DIRECTORY "${HOOK_STAMP_INCLUDE}")

function(hooks_stamp_configure_mark)
	file(WRITE "${HOOK_STAMP_INCLUDE}/hook_configure.stamp" "ok\n")
endfunction()

function(hooks_stamp_write)
	file(WRITE "${HOOK_STAMP_INCLUDE}/hook_generated.h"
		"#pragma once\n#define HOOK_STAMP 1\n")
endfunction()

buildmaster_hook_component(hooks-stamp hooks_stamp_configure_mark stamp-cfg
	CAPTURE HOOK_STAMP_INCLUDE
)
buildmaster_hook_graph(hooks_stamp_write stamp-hdr
	CAPTURE HOOK_STAMP_INCLUDE
)

_bm_backend_cmake_create(
	hooks-stamp
	"Harness hook stamp"
	"${CMAKE_CURRENT_SOURCE_DIR}/upstream"
	"-DHOOK_STAMP_INCLUDE=${HOOK_STAMP_INCLUDE}"
	static
	"hooks-stamp"
)
buildmaster_depend(hooks-stamp hook-a)
