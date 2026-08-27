# =============================================================================
# toolchain/profile.cmake — load named profiles into BM_TC_*
# =============================================================================

## @brief Load a toolchain profile into `BM_TC_*` variables in the caller scope.
## @param[in] name Normalized toolchain name (from
##            `buildmaster_validate_toolchain`).
## @note Includes `toolchain/profiles/<name>.cmake` which sets
##       `BM_TC_C_COMPILER`, `BM_TC_CXX_COMPILER`, `BM_TC_LINKER_TYPE`,
##       `BM_TC_LINKER`, `BM_TC_AR`, `BM_TC_RANLIB`, `BM_TC_NM`, and
##       `BM_TC_FORCE_LLD`. Values are exported to the caller with
##       `PARENT_SCOPE` (required because CMake functions isolate scope).
## @note Does **not** modify the parent project toolchain or the global env
##       runner. Empty `name` or a missing profile file is fatal.
function(buildmaster_load_toolchain_profile name)
	buildmaster_message(TOOLCHAIN LOWLEVEL "Entering buildmaster_load_toolchain_profile")
	if(name STREQUAL "")
		buildmaster_message(TOOLCHAIN FATAL "buildmaster_load_toolchain_profile: empty name")
	endif()

	set(_profile_file "${BUILDMASTER_TOOLCHAIN_PROFILES_DIR}/${name}.cmake")
	if(NOT EXISTS "${_profile_file}")
		buildmaster_message(TOOLCHAIN FATAL
			"Missing toolchain profile file: ${_profile_file}"
		)
	endif()

	include("${_profile_file}")

	# Profile sets BM_TC_* in this function scope only; export to caller.
	set(BM_TC_C_COMPILER "${BM_TC_C_COMPILER}" PARENT_SCOPE)
	set(BM_TC_CXX_COMPILER "${BM_TC_CXX_COMPILER}" PARENT_SCOPE)
	set(BM_TC_LINKER_TYPE "${BM_TC_LINKER_TYPE}" PARENT_SCOPE)
	set(BM_TC_LINKER "${BM_TC_LINKER}" PARENT_SCOPE)
	set(BM_TC_AR "${BM_TC_AR}" PARENT_SCOPE)
	set(BM_TC_RANLIB "${BM_TC_RANLIB}" PARENT_SCOPE)
	set(BM_TC_NM "${BM_TC_NM}" PARENT_SCOPE)
	set(BM_TC_FORCE_LLD "${BM_TC_FORCE_LLD}" PARENT_SCOPE)
	buildmaster_message(TOOLCHAIN DEBUG "Loaded profile ${name}")
	buildmaster_message(TOOLCHAIN LOWLEVEL "Exiting buildmaster_load_toolchain_profile")
endfunction()
