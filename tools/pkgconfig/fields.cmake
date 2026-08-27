# =============================================================================
# tools/pkgconfig/fields.cmake — helper .pc field assembly
# =============================================================================

## @brief Drop include-path tokens from a flag string.
## @param[in]  flags   Space-separated compiler flags.
## @param[out] out_var Parent-scope string without `-I`, `/I`, `-isystem`.
## @note Those paths belong to the BM prefix env, not to a helper .pc.
## @note Empty `flags` yields an empty string.
function(_buildmaster_pc_drop_include_tokens flags out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_pc_drop_include_tokens")
	set(_keep "")
	separate_arguments(_toks UNIX_COMMAND "${flags}")
	foreach(_t IN LISTS _toks)
		if(_t STREQUAL "")
			continue()
		endif()
		if(_t MATCHES "^[-/]I" OR _t STREQUAL "-isystem" OR _t MATCHES "^-isystem")
			continue()
		endif()
		list(APPEND _keep "${_t}")
	endforeach()
	string(REPLACE ";" " " _joined "${_keep}")
	string(STRIP "${_joined}" _joined)
	set(${out_var} "${_joined}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_pc_drop_include_tokens")
endfunction()

## @brief Tokens in `child` that are not in `parent`.
## @param[in]  parent  Parent job flags (space-separated).
## @param[in]  child   Component flags (space-separated).
## @param[out] out_var Parent-scope leftover string.
## @note Comparison is exact token match after `separate_arguments`.
function(_buildmaster_pc_subtract_parent parent child out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_pc_subtract_parent")
	separate_arguments(_p UNIX_COMMAND "${parent}")
	separate_arguments(_c UNIX_COMMAND "${child}")
	set(_out "")
	foreach(_t IN LISTS _c)
		if(_t STREQUAL "")
			continue()
		endif()
		set(_hit -1)
		if(_p)
			list(FIND _p "${_t}" _hit)
		endif()
		if(NOT _hit EQUAL -1)
			continue()
		endif()
		list(APPEND _out "${_t}")
	endforeach()
	string(REPLACE ";" " " _joined "${_out}")
	string(STRIP "${_joined}" _joined)
	set(${out_var} "${_joined}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_pc_subtract_parent")
endfunction()

## @brief Pull C/C++ flag strings out of a component option list.
## @param[in]  options Semicolon list (`-DCMAKE_C_FLAGS=…`, `-Dc_args=…`, …).
## @param[out] out_var Parent-scope combined flag string.
## @note Recognized prefixes: `-DCMAKE_C_FLAGS=`, `-DCMAKE_CXX_FLAGS=`,
##       `-Dc_args=`, `-Dcpp_args=`. Other options are ignored.
function(_buildmaster_pc_options_flags options out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_pc_options_flags")
	set(_acc "")
	foreach(_opt IN LISTS options)
		if(_opt MATCHES "^-DCMAKE_C_FLAGS=(.*)$")
			string(APPEND _acc " ${CMAKE_MATCH_1}")
		elseif(_opt MATCHES "^-DCMAKE_CXX_FLAGS=(.*)$")
			string(APPEND _acc " ${CMAKE_MATCH_1}")
		elseif(_opt MATCHES "^-Dc_args=(.*)$")
			string(APPEND _acc " ${CMAKE_MATCH_1}")
		elseif(_opt MATCHES "^-Dcpp_args=(.*)$")
			string(APPEND _acc " ${CMAKE_MATCH_1}")
		endif()
	endforeach()
	string(STRIP "${_acc}" _acc)
	set(${out_var} "${_acc}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_pc_options_flags")
endfunction()

## @brief Fill `_BM_PC_*` for `install_exec` / `create_*_stages`.
## @param[in] id Registered component id.
## @note Parent-scope: `_BM_PC_ENABLED` (`1`/`0`), `_BM_PC_NAME`,
##       `_BM_PC_VERSION`, `_BM_PC_DESCRIPTION`, `_BM_PC_LIBS`,
##       `_BM_PC_REQUIRES`, `_BM_PC_CFLAGS`, `_BM_PC_OUT`.
## @note Requires is direct `component_link` dests that are registered
##       components with PC enabled (not metas). Cflags are component
##       extras minus parent `CMAKE_C{,XX}_FLAGS`, minus include tokens.
## @note When PC is off, all string outs are empty and ENABLED is `0`.
function(_buildmaster_component_fill_pc_vars id)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_fill_pc_vars")
	get_property(_on GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_PC)
	if(NOT _on)
		set(_BM_PC_ENABLED "0" PARENT_SCOPE)
		set(_BM_PC_NAME "" PARENT_SCOPE)
		set(_BM_PC_VERSION "" PARENT_SCOPE)
		set(_BM_PC_DESCRIPTION "" PARENT_SCOPE)
		set(_BM_PC_LIBS "" PARENT_SCOPE)
		set(_BM_PC_REQUIRES "" PARENT_SCOPE)
		set(_BM_PC_CFLAGS "" PARENT_SCOPE)
		set(_BM_PC_OUT "" PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_fill_pc_vars")
		return()
	endif()

	get_property(_name GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_PC_NAME)
	get_property(_ver GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_PC_VERSION)
	get_property(_desc GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_PC_DESCRIPTION)
	get_property(_opts GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTIONS)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_PRODUCED)

	set(_libs "")
	foreach(_spec IN LISTS _produced)
		if(_spec STREQUAL "")
			continue()
		endif()
		buildmaster_parse_subcomponent("${_spec}" _ign_t _bn _ign_d)
		if(NOT _bn STREQUAL "")
			list(APPEND _libs "-l${_bn}")
		endif()
	endforeach()
	list(REMOVE_DUPLICATES _libs)
	string(REPLACE ";" " " _libs "${_libs}")

	set(_req "")
	get_property(_lsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
	if(_lsrcs)
		set(_i 0)
		foreach(_lsrc IN LISTS _lsrcs)
			list(GET _ldsts ${_i} _ldst)
			math(EXPR _i "${_i} + 1")
			if(NOT _lsrc STREQUAL "${id}")
				continue()
			endif()
			_buildmaster_component_is_registered("${_ldst}" _is_c)
			if(NOT _is_c)
				continue()
			endif()
			get_property(_dst_pc GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_ldst}_PC)
			if(NOT _dst_pc)
				continue()
			endif()
			get_property(_dst_name GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_ldst}_PC_NAME)
			if(NOT _dst_name STREQUAL "")
				list(APPEND _req "${_dst_name}")
			endif()
		endforeach()
	endif()
	if(_req)
		list(REMOVE_DUPLICATES _req)
	endif()
	string(REPLACE ";" ", " _req "${_req}")

	_buildmaster_pc_options_flags("${_opts}" _child_flags)
	set(_parent_flags "${CMAKE_C_FLAGS} ${CMAKE_CXX_FLAGS}")
	_buildmaster_pc_subtract_parent("${_parent_flags}" "${_child_flags}" _delta)
	_buildmaster_pc_drop_include_tokens("${_delta}" _cflags)

	set(_out "${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/${_name}.pc")

	set(_BM_PC_ENABLED "1" PARENT_SCOPE)
	set(_BM_PC_NAME "${_name}" PARENT_SCOPE)
	set(_BM_PC_VERSION "${_ver}" PARENT_SCOPE)
	set(_BM_PC_DESCRIPTION "${_desc}" PARENT_SCOPE)
	set(_BM_PC_LIBS "${_libs}" PARENT_SCOPE)
	set(_BM_PC_REQUIRES "${_req}" PARENT_SCOPE)
	set(_BM_PC_CFLAGS "${_cflags}" PARENT_SCOPE)
	set(_BM_PC_OUT "${_out}" PARENT_SCOPE)
	buildmaster_message(COMPONENT DEBUG "PC fields for ${id}: ${_name} ${_ver} → ${_out}")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_fill_pc_vars")
endfunction()
