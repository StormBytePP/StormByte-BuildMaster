## @brief Persist BuildMaster directory-scope bootstrap variables into the CMake cache.
## @note `cmake_language(DEFER DIRECTORY CMAKE_SOURCE_DIR)` runs finalize in the
##       host root. `add_subdirectory(thirdparty/buildmaster)` only PARENT_SCOPE
##       one level (thirdparty), so template roots such as
##       BUILDMASTER_TOOLS_CMAKE_SRCDIR would be empty at DEFER
##       (`File /configure.cmake.in does not exist`). Cache INTERNAL is visible
##       in every directory. Idempotent. Does not persist CMAKE_* flags.
## @note `NPROC` is not a BUILDMASTER_* / ENV_* name but Meson/CMake stage
##       templates substitute `@NPROC@` (`--jobs` / `--parallel`) at DEFER.
##       Without a cache entry the value is empty and Meson errors with
##       `argument -j/--jobs: expected one argument`.
function(buildmaster_persist_bootstrap)
	buildmaster_message(CORE LOWLEVEL "Entering buildmaster_persist_bootstrap")
	get_cmake_property(_bm_vars VARIABLES)
	foreach(_bm_v IN LISTS _bm_vars)
		if(_bm_v MATCHES "^BUILDMASTER_" OR _bm_v MATCHES "^ENV_")
			set(${_bm_v} "${${_bm_v}}" CACHE INTERNAL
				"BuildMaster persisted bootstrap variable")
		endif()
	endforeach()
	if(DEFINED NPROC AND NOT "${NPROC}" STREQUAL "")
		set(NPROC "${NPROC}" CACHE INTERNAL
			"BuildMaster persisted job count")
	endif()
	buildmaster_message(CORE LOWLEVEL "Exiting buildmaster_persist_bootstrap")
endfunction()
