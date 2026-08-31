#fixture bundled pkgconf even when the runner has system pkg-config

set(BUILDMASTER_TOOLS_PKGCONFIG_FORCE_BUNDLED ON CACHE BOOL
	"harness: compile bundled pkgconf" FORCE)

buildmaster_component(
	req-pkgconfig
	"Harness REQUIRE_TOOL pkgconfig"
	"${CMAKE_CURRENT_SOURCE_DIR}/tree"
	""
	headers
	""
	"REQUIRE_TOOL=pkgconfig"
)

if(NOT PKG_CONFIG)
	message(FATAL_ERROR "require-tool-pkgconfig: PKG_CONFIG is empty")
endif()
if(NOT EXISTS "${PKG_CONFIG}")
	message(FATAL_ERROR "require-tool-pkgconfig: missing ${PKG_CONFIG}")
endif()

file(TO_CMAKE_PATH "${BUILDMASTER_INSTALL_BINDIR}" _bm_bindir)
file(TO_CMAKE_PATH "${PKG_CONFIG}" _bm_pc)
string(FIND "${_bm_pc}" "${_bm_bindir}" _bm_idx)
if(_bm_idx EQUAL -1)
	message(FATAL_ERROR
		"require-tool-pkgconfig: PKG_CONFIG='${PKG_CONFIG}' is not under '${BUILDMASTER_INSTALL_BINDIR}'")
endif()

execute_process(
	COMMAND ${ENV_RUNNER} "${PKG_CONFIG}" --version
	RESULT_VARIABLE _bm_pc_rc
	OUTPUT_VARIABLE _bm_pc_ver
	ERROR_VARIABLE _bm_pc_err
)
if(NOT _bm_pc_rc EQUAL 0)
	message(FATAL_ERROR
		"require-tool-pkgconfig: bundled --version failed:\n${_bm_pc_err}")
endif()

_bm_log_message(CORE STATUS "require-tool-pkgconfig: ${PKG_CONFIG} ${_bm_pc_ver} OK")
