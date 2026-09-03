# =============================================================================
# toolchain/parent_link.cmake — GNU rescan on the parent link recipe
# =============================================================================

## @brief Wrap parent CMAKE_<LANG>_LINK_EXECUTABLE with --start-group.
## @note Linux gcc/clang only. ld.bfd visits a static archive once; an
##       exe that lists A before B when B needs A drops symbols under
##       LTO. Darwin ld64 and MSVC/clang-cl scan archives; group tokens
##       stay empty. SHARED/MODULE recipes are not touched.
## @note No-op if the recipe already contains --start-group.
## @note Called from `toolchain/CMakeLists.txt` after helpers load.
##       Nested bootstrap never reaches that CMakeLists.
function(_bm_tc_apply_parent_link_group)
	_bm_log_message(TOOLCHAIN LOWLEVEL "Entering _bm_tc_apply_parent_link_group")
	if(APPLE OR WIN32 OR MSVC)
		_bm_log_message(TOOLCHAIN LOWLEVEL
			"Exiting _bm_tc_apply_parent_link_group (not GNU ELF)")
		return()
	endif()
	_bm_tc_infer_profile(_prof)
	if(NOT _prof STREQUAL "gcc" AND NOT _prof STREQUAL "clang")
		_bm_log_message(TOOLCHAIN LOWLEVEL
			"Exiting _bm_tc_apply_parent_link_group (profile ${_prof})")
		return()
	endif()

	set(_s "-Wl,--start-group")
	set(_e "-Wl,--end-group")
	foreach(_lang IN ITEMS C CXX)
		set(_var "CMAKE_${_lang}_LINK_EXECUTABLE")
		if(NOT DEFINED ${_var} OR "${${_var}}" STREQUAL "")
			if(_lang STREQUAL "C")
				set(_cc "<CMAKE_C_COMPILER>")
				set(_lf "<CMAKE_C_LINK_FLAGS>")
			else()
				set(_cc "<CMAKE_CXX_COMPILER>")
				set(_lf "<CMAKE_CXX_LINK_FLAGS>")
			endif()
			set(_recipe
				"${_cc} <FLAGS> ${_lf} <LINK_FLAGS> <OBJECTS> -o <TARGET> ${_s} <LINK_LIBRARIES> ${_e}")
		else()
			set(_recipe "${${_var}}")
			if(_recipe MATCHES "--start-group")
				continue()
			endif()
			string(REPLACE "<LINK_LIBRARIES>"
				"${_s} <LINK_LIBRARIES> ${_e}" _recipe "${_recipe}")
		endif()
		set(${_var} "${_recipe}" PARENT_SCOPE)
		set(${_var} "${_recipe}" CACHE STRING
			"BuildMaster GNU rescan link recipe (${_lang})" FORCE)
	endforeach()
	_bm_log_message(TOOLCHAIN DEBUG
		"parent LINK_EXECUTABLE wrapped with --start-group (profile ${_prof})")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_apply_parent_link_group")
endfunction()
