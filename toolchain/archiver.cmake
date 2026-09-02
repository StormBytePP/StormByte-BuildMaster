# =============================================================================
# toolchain/archiver.cmake — AR is part of the toolchain profile, not a tool
# =============================================================================

## @brief Classify an archiver binary.
## @param[in]  path      Absolute path or basename.
## @param[out] out_style Parent-scope `msvc_lib` or `gnu_ar`.
function(_bm_tc_archiver_style path out_style)
	get_filename_component(_name "${path}" NAME)
	string(TOLOWER "${_name}" _name_l)
	set(_style "gnu_ar")
	if(_name_l MATCHES "llvm-lib" OR _name_l STREQUAL "lib"
			OR _name_l MATCHES "lib\\.exe$")
		set(_style "msvc_lib")
	endif()
	set(${out_style} "${_style}" PARENT_SCOPE)
endfunction()

## @brief Resolve BM_TC_AR for one profile to an absolute path + style.
## @param[in]  profile   Normalized name (`msvc`, `clang-cl`, `gcc`, `clang`).
## @param[out] out_path  Parent-scope absolute path.
## @param[out] out_style Parent-scope `msvc_lib` or `gnu_ar`.
## @note Uses only the profile's BM_TC_AR (and MSVC toolset resolve).
##       Does not consult the parent CMAKE_AR / ENV{AR} — those belong
##       to another toolchain.
## @note Missing AR is FATAL: the toolchain is incomplete.
function(_bm_tc_archiver_resolve profile out_path out_style)
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Entering _bm_tc_archiver_resolve profile='${profile}'")
	if(profile STREQUAL "")
		_bm_log_message(TOOLCHAIN FATAL
			"_bm_tc_archiver_resolve: empty profile")
	endif()

	_bm_tc_load_profile("${profile}")
	if(BM_TC_AR STREQUAL "")
		_bm_log_message(TOOLCHAIN FATAL
			"toolchain profile '${profile}' has empty BM_TC_AR")
	endif()

	set(_ar "${BM_TC_AR}")
	if(profile STREQUAL "msvc")
		_bm_tc_resolve_msvc_tool(_ar "${_ar}")
	elseif(IS_ABSOLUTE "${_ar}" AND EXISTS "${_ar}")
		_bm_path_normalize(_ar "${_ar}")
	else()
		string(MAKE_C_IDENTIFIER "${profile}_${_ar}" _cid)
		find_program(_BM_TC_AR_${_cid} NAMES "${_ar}" "${_ar}.exe")
		if(_BM_TC_AR_${_cid})
			_bm_path_normalize(_ar "${_BM_TC_AR_${_cid}}")
		else()
			_bm_log_message(TOOLCHAIN FATAL
				"toolchain profile '${profile}': archiver '${BM_TC_AR}' not found")
		endif()
	endif()

	if(NOT EXISTS "${_ar}")
		_bm_log_message(TOOLCHAIN FATAL
			"toolchain profile '${profile}': archiver path missing: ${_ar}")
	endif()

	_bm_tc_archiver_style("${_ar}" _style)
	set(${out_path} "${_ar}" PARENT_SCOPE)
	set(${out_style} "${_style}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG
		"profile '${profile}' AR=${_ar} style=${_style}")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_archiver_resolve")
endfunction()
