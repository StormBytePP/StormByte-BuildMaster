# Component TOOLCHAIN dump must carry trunk INSTALL_DIR / ROOT / CONFIGURED.
# Regression: overlay-only dump → nested BM creates a second prefix.

file(GLOB _bm_tc_dumps
	"${BUILDMASTER_SCRIPTSDIR}/toolchain_tc-prefix_*.cmake")
if(NOT _bm_tc_dumps)
	message(FATAL_ERROR
		"tc-prefix: no toolchain_tc-prefix_*.cmake under '${BUILDMASTER_SCRIPTSDIR}'")
endif()

file(TO_CMAKE_PATH "${BUILDMASTER_INSTALL_DIR}" _bm_want_prefix)
file(TO_CMAKE_PATH "${BUILDMASTER_ROOT}" _bm_want_root)

foreach(_bm_dump IN LISTS _bm_tc_dumps)
	file(READ "${_bm_dump}" _bm_txt)
	if(NOT _bm_txt MATCHES "set\\(BUILDMASTER_CONFIGURED TRUE\\)")
		message(FATAL_ERROR
			"tc-prefix: '${_bm_dump}' missing BUILDMASTER_CONFIGURED TRUE")
	endif()
	if(NOT _bm_txt MATCHES "set\\(BUILDMASTER_INSTALL_DIR \"${_bm_want_prefix}\"\\)")
		message(FATAL_ERROR
			"tc-prefix: '${_bm_dump}' missing INSTALL_DIR=${_bm_want_prefix}")
	endif()
	if(NOT _bm_txt MATCHES "set\\(BUILDMASTER_ROOT \"${_bm_want_root}\"\\)")
		message(FATAL_ERROR
			"tc-prefix: '${_bm_dump}' missing ROOT=${_bm_want_root}")
	endif()
	_bm_log_message(CORE STATUS "tc-prefix: dump OK ${_bm_dump}")
endforeach()
