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

if(NOT DEFINED PKG_CONFIG_PATH OR PKG_CONFIG_PATH STREQUAL "")
	message(FATAL_ERROR "require-tool-pkgconfig: PKG_CONFIG_PATH is empty")
endif()
file(TO_CMAKE_PATH "${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig" _bm_want_pc)
file(TO_CMAKE_PATH "${PKG_CONFIG_PATH}" _bm_got_pc)
if(NOT _bm_got_pc STREQUAL _bm_want_pc)
	message(FATAL_ERROR
		"require-tool-pkgconfig: PKG_CONFIG_PATH='${PKG_CONFIG_PATH}' want '${_bm_want_pc}'")
endif()

if(WIN32)
	set(_bm_runner_file "${BUILDMASTER_SCRIPTS_ENVDIR}/runner.ps1")
else()
	set(_bm_runner_file "${BUILDMASTER_SCRIPTS_ENVDIR}/runner.sh")
endif()
if(NOT EXISTS "${_bm_runner_file}")
	message(FATAL_ERROR
		"require-tool-pkgconfig: missing runner ${_bm_runner_file}")
endif()
file(READ "${_bm_runner_file}" _bm_runner_txt)
string(FIND "${_bm_runner_txt}" "${_bm_want_pc}" _bm_runner_hit)
if(_bm_runner_hit EQUAL -1)
	message(FATAL_ERROR
		"require-tool-pkgconfig: runner '${_bm_runner_file}' does not contain PKG_CONFIG_PATH '${_bm_want_pc}'")
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

_bm_log_message(CORE STATUS
	"require-tool-pkgconfig: ${PKG_CONFIG} ${_bm_pc_ver} path=${PKG_CONFIG_PATH} OK")
	