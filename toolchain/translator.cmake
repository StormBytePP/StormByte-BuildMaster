# =============================================================================
# toolchain/translator.cmake — dialect + IPO rewrite of C/CXX/LD flags
# =============================================================================
# Not a public API. Callers: tools/meson/stages.cmake (and later CMake
# wrappers). Does not set b_lto or CMAKE_INTERPROCEDURAL_*.
# Cache key: profile + IPO on/off + hash of the three input strings.

## @brief Infer BM profile from this process's C compiler.
## @param[out] out Variable name for `gcc`, `clang`, `clang-cl`, or `msvc`.
function(_bm_tc_infer_profile out)
	if(CMAKE_C_COMPILER MATCHES "clang-cl" OR CMAKE_CXX_COMPILER MATCHES "clang-cl")
		set(${out} "clang-cl" PARENT_SCOPE)
	elseif(MSVC OR CMAKE_C_COMPILER MATCHES "cl\\.exe")
		set(${out} "msvc" PARENT_SCOPE)
	elseif(CMAKE_C_COMPILER MATCHES "clang" OR CMAKE_CXX_COMPILER MATCHES "clang")
		set(${out} "clang" PARENT_SCOPE)
	else()
		set(${out} "gcc" PARENT_SCOPE)
	endif()
endfunction()

## @brief True if CMake IPO is on or `flags` already contain an IPO token.
function(_bm_tc_ipo_wanted out flags)
	set(_on FALSE)
	if(CMAKE_INTERPROCEDURAL_OPTIMIZATION)
		set(_on TRUE)
	endif()
	if(CMAKE_BUILD_TYPE STREQUAL "Release" AND CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE)
		set(_on TRUE)
	endif()
	if(flags MATCHES "(^| )(-flto|/GL|/LTCG)([= ]|$)")
		set(_on TRUE)
	endif()
	set(${out} "${_on}" PARENT_SCOPE)
endfunction()

## @brief Drop foreign dialect and every IPO token. Convert -I/-L ↔ /I /LIBPATH.
## @param[in] profile Destination BM profile.
## @param[in] in Input flag string.
## @param[out] out Cleaned string (no IPO tokens).
function(_bm_tc_sanitize_flag_string profile in out)
	set(_toks "")
	separate_arguments(_raw NATIVE_COMMAND "${in}")
	foreach(_t IN LISTS _raw)
		if(_t STREQUAL "")
			continue()
		endif()
		# Pass 1: strip IPO always.
		if(_t MATCHES "^-flto" OR _t STREQUAL "/GL" OR _t STREQUAL "/GL-" OR _t STREQUAL "/LTCG")
			continue()
		endif()
		if(_t MATCHES "^-fwhole-program")
			continue()
		endif()
		# -fuse-ld=* is never a valid MSVC link.exe flag.
		if(_t MATCHES "^-fuse-ld=")
			if(profile STREQUAL "msvc")
				continue()
			endif()
			# clang/gcc/clang-cl: drop here; pass 2 does not re-add fuse-ld.
			# Native file already has ld=.
			continue()
		endif()
		if(profile STREQUAL "msvc")
			if(_t MATCHES "^-f" OR _t MATCHES "^-W" OR _t MATCHES "^-Wl," OR _t MATCHES "^-pthread")
				continue()
			endif()
			if(_t MATCHES "^-I(.+)$")
				set(_t "/I${CMAKE_MATCH_1}")
			elseif(_t MATCHES "^-L(.+)$")
				set(_t "/LIBPATH:${CMAKE_MATCH_1}")
			endif()
		else()
			if(_t MATCHES "^/I(.+)$")
				set(_t "-I${CMAKE_MATCH_1}")
			elseif(_t MATCHES "^/LIBPATH:(.+)$")
				set(_t "-L${CMAKE_MATCH_1}")
			endif()
			if(_t MATCHES "^/[A-Za-z]" AND NOT _t MATCHES "^/I")
				# Other cl.exe tokens are foreign on gcc/clang.
				continue()
			endif()
		endif()
		if(profile STREQUAL "clang-cl")
			if(_t STREQUAL "/LTCG" OR _t STREQUAL "/GL")
				continue()
			endif()
		endif()
		list(APPEND _toks "${_t}")
	endforeach()
	string(JOIN " " _joined ${_toks})
	string(STRIP "${_joined}" _joined)
	set(${out} "${_joined}" PARENT_SCOPE)
endfunction()

## @brief Rewrite C/CXX/LD flags for `profile`. Cached per profile+IPO+hash.
## @param[in,out] c_var Name of the CFLAGS variable.
## @param[in,out] cxx_var Name of the CXXFLAGS variable.
## @param[in,out] ld_var Name of the LDFLAGS variable.
## @param[in] profile `gcc`, `clang`, `clang-cl`, or `msvc`.
## @note After a miss, callers must refresh the env runner so it exports
##       the translated strings (stages does this).
function(_bm_tc_translate_flags c_var cxx_var ld_var profile)
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Entering _bm_tc_translate_flags(${profile})")
	if(profile STREQUAL "")
		_bm_log_message(TOOLCHAIN FATAL "_bm_tc_translate_flags: empty profile")
	endif()

	set(_c "${${c_var}}")
	set(_cxx "${${cxx_var}}")
	set(_ld "${${ld_var}}")
	_bm_tc_ipo_wanted(_ipo "${_c} ${_cxx} ${_ld}")
	if(_ipo)
		set(_ipo_key "on")
	else()
		set(_ipo_key "off")
	endif()
	string(SHA1 _h "${profile}|${_ipo_key}|${_c}|${_cxx}|${_ld}")
	set(_prop "BUILDMASTER_TC_TRANSLATED_${profile}_${_ipo_key}_${_h}")
	get_property(_hit GLOBAL PROPERTY "${_prop}")
	if(_hit)
		list(GET _hit 0 _c)
		list(GET _hit 1 _cxx)
		list(GET _hit 2 _ld)
		set(${c_var} "${_c}" PARENT_SCOPE)
		set(${cxx_var} "${_cxx}" PARENT_SCOPE)
		set(${ld_var} "${_ld}" PARENT_SCOPE)
		_bm_log_message(TOOLCHAIN LOWLEVEL
			"Exiting _bm_tc_translate_flags(${profile}) (cache)")
		return()
	endif()

	_bm_tc_sanitize_flag_string("${profile}" "${_c}" _c)
	_bm_tc_sanitize_flag_string("${profile}" "${_cxx}" _cxx)
	_bm_tc_sanitize_flag_string("${profile}" "${_ld}" _ld)

	if(_ipo)
		if(profile STREQUAL "msvc")
			string(APPEND _c " /GL")
			string(APPEND _cxx " /GL")
			string(APPEND _ld " /LTCG")
		elseif(profile STREQUAL "clang-cl")
			string(APPEND _c " -flto")
			string(APPEND _cxx " -flto")
			string(APPEND _ld " -flto")
		else()
			string(APPEND _c " -flto")
			string(APPEND _cxx " -flto")
			string(APPEND _ld " -flto")
		endif()
		string(STRIP "${_c}" _c)
		string(STRIP "${_cxx}" _cxx)
		string(STRIP "${_ld}" _ld)
	endif()

	set_property(GLOBAL PROPERTY "${_prop}" "${_c};${_cxx};${_ld}")
	set(${c_var} "${_c}" PARENT_SCOPE)
	set(${cxx_var} "${_cxx}" PARENT_SCOPE)
	set(${ld_var} "${_ld}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG
		"translated ${profile} ipo=${_ipo_key} c='${_c}' ld='${_ld}'")
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Exiting _bm_tc_translate_flags(${profile})")
endfunction()
