# -----------------------------------------------------------------------------
# Version (pin local, before any redirect)
# -----------------------------------------------------------------------------
function(_bm_read_version_file _dir _out)
	set(_file "${_dir}/VERSION")
	set(_ver "pre-2.0.0")
	if(EXISTS "${_file}")
		file(READ "${_file}" _ver)
		string(STRIP "${_ver}" _ver)
		if(_ver STREQUAL "")
			set(_ver "pre-2.0.0")
		endif()
	endif()
	set(${_out} "${_ver}" PARENT_SCOPE)
endfunction()

function(_bm_warn_version_mismatch _pin _pindir _trunk _trunkdir)
	if(NOT _pin STREQUAL _trunk)
		_bm_log_message(CORE WARNING
			"BuildMaster pin ${_pin} (${_pindir}) does not match trunk ${_trunk} (${_trunkdir}). Match submodule versions.")
	endif()
endfunction()

set(_BM_PIN_SRCDIR "${CMAKE_CURRENT_LIST_DIR}")
_bm_read_version_file("${_BM_PIN_SRCDIR}" _BM_PIN_VERSION)
set(BUILDMASTER_VERSION "${_BM_PIN_VERSION}")
set(BUILDMASTER_VERSION "${BUILDMASTER_VERSION}" PARENT_SCOPE)

# -----------------------------------------------------------------------------
# Trunk pointer — cache (same cmake process) + toolchain (nested cmake)
# -----------------------------------------------------------------------------
if(NOT DEFINED BUILDMASTER_ROOT OR "${BUILDMASTER_ROOT}" STREQUAL "")
	if(DEFINED CACHE{BUILDMASTER_ROOT} AND NOT "$CACHE{BUILDMASTER_ROOT}" STREQUAL "")
		set(BUILDMASTER_ROOT "$CACHE{BUILDMASTER_ROOT}")
	endif()
endif()

if(DEFINED BUILDMASTER_ROOT AND NOT "${BUILDMASTER_ROOT}" STREQUAL ""
		AND NOT _BM_PIN_SRCDIR STREQUAL BUILDMASTER_ROOT)
	include("${BUILDMASTER_ROOT}/log.cmake")
	_bm_log_level_init()
	_bm_read_version_file("${BUILDMASTER_ROOT}" _BM_TRUNK_VERSION)
	_bm_warn_version_mismatch(
		"${_BM_PIN_VERSION}" "${_BM_PIN_SRCDIR}"
		"${_BM_TRUNK_VERSION}" "${BUILDMASTER_ROOT}")
	include("${BUILDMASTER_ROOT}/helpers.cmake")
	include("${BUILDMASTER_ROOT}/tools/helpers.cmake")
	include("${BUILDMASTER_ROOT}/propagate_vars.cmake")
	include("${BUILDMASTER_ROOT}/persist.cmake")
	_bm_core_persist_bootstrap()
	return()
endif()

# -----------------------------------------------------------------------------
# 0. Log API (init_vars and helpers may call _bm_log_level_init)
# -----------------------------------------------------------------------------
include(log.cmake)
_bm_log_level_init()

# -----------------------------------------------------------------------------
# 1. Core directory variables
# -----------------------------------------------------------------------------
# When the host project was configured with -DCMAKE_TOOLCHAIN_FILE pointing at
# an existing BuildMaster toolchain.cmake, that file already set
# BUILDMASTER_CONFIGURED and the full BUILDMASTER_* / ENV_* snapshot. init_vars
# then skips path creation (paths come from the toolchain only).
include(init_vars.cmake)

# -----------------------------------------------------------------------------
# Nested bootstrap guard
# -----------------------------------------------------------------------------
# Nested projects (e.g. Buffer → Logger → Base) load the *same* shared
# BUILDMASTER_TOOLCHAIN_FILE as CMAKE_TOOLCHAIN_FILE. They then
# add_subdirectory(buildmaster). If we ran the full bootstrap again we would:
#   - _bm_tc_reset() clear the in-memory registry
#   - re-export only the root update_toolchain lines
#   - _bm_tc_write() overwrite the parent toolchain.cmake with an
#     incomplete file (missing TOOLS_CMAKE_SRCDIR, COMPONENT_SRCDIR, ENV_*, …)
# That incomplete file is what later causes:
#   File /templates/configure.cmake.in does not exist
#   File /component_shared.cmake.in does not exist
#
# Order matters: this check runs after init_vars (so CONFIGURED from the
# toolchain is visible) and before any reset/write or add_subdirectory of
# modules. Nested hosts still need helpers.cmake so create_* APIs remain
# available; then we propagate and stop.
if(BUILDMASTER_CONFIGURED)
	_bm_read_version_file("${BUILDMASTER_ROOT}" _BM_TRUNK_VERSION)
	_bm_warn_version_mismatch(
		"${_BM_PIN_VERSION}" "${_BM_PIN_SRCDIR}"
		"${_BM_TRUNK_VERSION}" "${BUILDMASTER_ROOT}")
	include("${BUILDMASTER_ROOT}/helpers.cmake")
	include("${BUILDMASTER_ROOT}/tools/helpers.cmake")
	include(propagate_vars.cmake)
	include(persist.cmake)
	_bm_core_persist_bootstrap()
	return()
endif()

# This tree is the trunk.
set(BUILDMASTER_ROOT "${_BM_PIN_SRCDIR}" CACHE INTERNAL
	"Source tree of the trunk BuildMaster")
set(BUILDMASTER_VERSION "${_BM_PIN_VERSION}" CACHE INTERNAL
	"Trunk BuildMaster version")

_bm_log_message(CORE STATUS
	"Bootstrapping StormByte-BuildMaster ${BUILDMASTER_VERSION} (https://github.com/StormBytePP/StormByte-BuildMaster)")

# -----------------------------------------------------------------------------
# 2. Helper functions (utilities + module helpers; loads toolchain export API)
# -----------------------------------------------------------------------------
include("${BUILDMASTER_ROOT}/helpers.cmake")

# -----------------------------------------------------------------------------
# 3. Toolchain registry (primary bootstrap only)
# -----------------------------------------------------------------------------
# Reset must run before any export*. Modules register lines into a global
# property; a single write at the end materializes toolchain.cmake. Never call
# reset/write from a nested bootstrap (guard above).
_bm_tc_reset()
include("${BUILDMASTER_SRCDIR}/update_toolchain.cmake")

# -----------------------------------------------------------------------------
# 4. Toolchain profiles (validate / resolve; used by env, tools, component)
# -----------------------------------------------------------------------------
# Profiles and known-toolchain list are registered into the dump via this
# module's update_toolchain.cmake (included from its init_vars while
# CONFIGURED is still false).
add_subdirectory(toolchain)
include(toolchain/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 5. Environment runners
# -----------------------------------------------------------------------------
add_subdirectory(env)
include(env/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 6. Tools (cmake, git, meson, ninja, extra, file, …)
# -----------------------------------------------------------------------------
# Each tool's init_vars registers BUILDMASTER_TOOLS_*_SRCDIR, SCRIPTS_* and
# ENV_* into the registry. These exports must happen before the final write
# or nested configures will lack template roots.
add_subdirectory(tools)
include(tools/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 7. Component helpers
# -----------------------------------------------------------------------------
add_subdirectory(component)
include(component/propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 8. Materialize parent toolchain.cmake from the full registry
# -----------------------------------------------------------------------------
# Single write after every module has registered. This file is the sole source
# of truth for nested projects (CONFIGURED=TRUE path above).
_bm_tc_write("${BUILDMASTER_TOOLCHAIN_FILE}")

# Same-process children (Buffer → Logger) do not load the dump. Cache it.
set(BUILDMASTER_CONFIGURED TRUE CACHE INTERNAL
	"Trunk BuildMaster already bootstrapped")
set(BUILDMASTER_CONFIGURED TRUE)

# -----------------------------------------------------------------------------
# 9. Final propagation to the parent scope
# -----------------------------------------------------------------------------
include(propagate_vars.cmake)

# -----------------------------------------------------------------------------
# 10. Persist bootstrap vars for DEFER at CMAKE_SOURCE_DIR
# -----------------------------------------------------------------------------
# Hosts that add_subdirectory(thirdparty/buildmaster) only receive PARENT_SCOPE
# one directory up (thirdparty). Finalize runs in the host root.
include(persist.cmake)
_bm_core_persist_bootstrap()
