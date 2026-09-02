# =============================================================================
# toolchain/translator.cmake — dialect + IPO + forced -fuse-ld=
# =============================================================================
# Not public. Called from cmake/meson stages before the env runner refresh.
# Pass 1: drop foreign dialect, rewrite -I/-L on MSVC-like, drop IPO and
#         every -fuse-ld=.
# Pass 2: IPO tokens of this profile (or nothing).
# Pass 3: -fuse-ld= of this profile only (gcc=bfd, clang/clang-cl=lld,
#         msvc=none). Always, not only when IPO is on.
#         clang-cl Meson sanity puts link_args after /link; the driver
#         only honors -fuse-ld= on the compiler command. Put it on
#         C/CXX as well as LD.

function(_bm_tc_flag_has hay needle)
	string(FIND " ${hay} " " ${needle} " _pos)
	if(_pos EQUAL -1)
		set(_bm_tc_flag_has_result FALSE PARENT_SCOPE)
	else()
		set(_bm_tc_flag_has_result TRUE PARENT_SCOPE)
	endif()
endfunction()

function(_bm_tc_flag_append io_var token)
	if("${token}" STREQUAL "")
		return()
	endif()
	set(_cur "${${io_var}}")
	_bm_tc_flag_has("${_cur}" "${token}")
	if(_bm_tc_flag_has_result)
		return()
	endif()
	if(_cur STREQUAL "")
		set(${io_var} "${token}" PARENT_SCOPE)
	else()
		set(${io_var} "${_cur} ${token}" PARENT_SCOPE)
	endif()
endfunction()

function(_bm_tc_ipo_wanted c_str cxx_str ld_str out_var)
	set(_yes FALSE)
	if(CMAKE_INTERPROCEDURAL_OPTIMIZATION)
		set(_yes TRUE)
	endif()
	if(NOT _yes AND DEFINED CMAKE_BUILD_TYPE AND NOT CMAKE_BUILD_TYPE STREQUAL "")
		string(TOUPPER "${CMAKE_BUILD_TYPE}" _bt)
		if(CMAKE_INTERPROCEDURAL_OPTIMIZATION_${_bt})
			set(_yes TRUE)
		endif()
	endif()
	if(NOT _yes)
		foreach(_s IN ITEMS "${c_str}" "${cxx_str}" "${ld_str}")
			if(_s MATCHES "(^| )(-flto|/GL|/LTCG|-fwhole-program-vtables)( |$)")
				set(_yes TRUE)
				break()
			endif()
		endforeach()
	endif()
	set(${out_var} "${_yes}" PARENT_SCOPE)
endfunction()

## @brief Drop foreign dialect and IPO tokens from one flag string.
## @param[in]  in_str  Raw flag string.
## @param[in]  profile gcc|clang|clang-cl|msvc
## @param[out] out_var Sanitized string.
## @note msvc/clang-cl: `-I`→`/I`, `-L`→`/LIBPATH:`. Unix `-fPIC` / `-f*`
##       stay on gcc/clang — they are not noise. msvc drops `-f*` / `-W*`
##       because those are not cl.exe.
## @note Unix profiles: `/I`→`-I`, `/LIBPATH:`→`-L`, `/O[0-3d]`→`-O…`.
##       `/GL` `/LTCG` `/Z7` are dropped (IPO/debug MSVC).
function(_bm_tc_sanitize_flag_string in_str profile out_var)
	set(_out "")
	set(_msvc_like FALSE)
	if(profile STREQUAL "msvc" OR profile STREQUAL "clang-cl")
		set(_msvc_like TRUE)
	endif()
	separate_arguments(_tok UNIX_COMMAND "${in_str}")
	foreach(_t IN LISTS _tok)
		if(_t STREQUAL "")
			continue()
		endif()
		if(_t MATCHES "^-flto" OR _t STREQUAL "/GL" OR _t STREQUAL "/LTCG"
				OR _t STREQUAL "-fwhole-program-vtables"
				OR _t MATCHES "^-fuse-ld=")
			continue()
		endif()
		if(_msvc_like)
			if(_t MATCHES "^-I(.+)$")
				set(_t "/I${CMAKE_MATCH_1}")
			elseif(_t MATCHES "^-L(.+)$")
				set(_t "/LIBPATH:${CMAKE_MATCH_1}")
			elseif(_t MATCHES "^-f" OR _t MATCHES "^-W" OR _t STREQUAL "-pthread")
				continue()
			endif()
		else()
			if(_t STREQUAL "/GL" OR _t MATCHES "^/LTCG" OR _t STREQUAL "/Z7"
					OR _t STREQUAL "/Zi" OR _t STREQUAL "/FS")
				continue()
			endif()
			if(_t MATCHES "^/I(.+)$")
				set(_t "-I${CMAKE_MATCH_1}")
			elseif(_t MATCHES "^/LIBPATH:(.+)$")
				set(_t "-L${CMAKE_MATCH_1}")
			elseif(_t MATCHES "^/O([0-3d])$")
				set(_t "-O${CMAKE_MATCH_1}")
			elseif(_t MATCHES "^/")
				continue()
			endif()
		endif()
		if(_out STREQUAL "")
			set(_out "${_t}")
		else()
			set(_out "${_out} ${_t}")
		endif()
	endforeach()
	set(${out_var} "${_out}" PARENT_SCOPE)
endfunction()

## @brief Translate C/CXX/LD strings into @p profile. Updates PARENT_SCOPE.
## @param[in,out] c_var   Name of the C flags variable.
## @param[in,out] cxx_var Name of the CXX flags variable.
## @param[in,out] ld_var  Name of the linker flags variable.
## @param[in]     profile gcc|clang|clang-cl|msvc
## @note Linux gcc: `-fuse-ld=bfd` on LD only.
##       Linux clang: `-fuse-ld=lld` on LD only.
##       Darwin gcc/clang: no `-fuse-ld` (ld64; CMake rejects BFD).
##       clang-cl: `-fuse-ld=lld` on C/CXX and LD (Meson `/link` order).
function(_bm_tc_translate_flags c_var cxx_var ld_var profile)
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Entering _bm_tc_translate_flags(${profile})")
	set(_c "${${c_var}}")
	set(_cxx "${${cxx_var}}")
	set(_ld "${${ld_var}}")

	_bm_tc_ipo_wanted("${_c}" "${_cxx}" "${_ld}" _ipo)
	_bm_tc_sanitize_flag_string("${_c}" "${profile}" _c)
	_bm_tc_sanitize_flag_string("${_cxx}" "${profile}" _cxx)
	_bm_tc_sanitize_flag_string("${_ld}" "${profile}" _ld)

	if(_ipo)
		if(profile STREQUAL "msvc")
			_bm_tc_flag_append(_c "/GL")
			_bm_tc_flag_append(_cxx "/GL")
			_bm_tc_flag_append(_ld "/LTCG")
		else()
			_bm_tc_flag_append(_c "-flto")
			_bm_tc_flag_append(_cxx "-flto")
			_bm_tc_flag_append(_ld "-flto")
		endif()
	endif()

	if(profile STREQUAL "gcc" AND NOT APPLE)
		_bm_tc_flag_append(_ld "-fuse-ld=bfd")
	elseif(profile STREQUAL "clang" AND NOT APPLE)
		_bm_tc_flag_append(_ld "-fuse-ld=lld")
	elseif(profile STREQUAL "clang-cl")
		_bm_tc_flag_append(_c "-fuse-ld=lld")
		_bm_tc_flag_append(_cxx "-fuse-ld=lld")
		_bm_tc_flag_append(_ld "-fuse-ld=lld")
	endif()

	set(${c_var} "${_c}" PARENT_SCOPE)
	set(${cxx_var} "${_cxx}" PARENT_SCOPE)
	set(${ld_var} "${_ld}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG
		"translate ${profile} ipo=${_ipo} c='${_c}' ld='${_ld}'")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_translate_flags")
endfunction()
