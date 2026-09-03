# =============================================================================
# toolchain/translator.cmake — dialect + IPO + forced -fuse-ld=
# =============================================================================
# Not public. Called from cmake/meson stages before the env runner refresh.
# Pass 1: drop foreign dialect, rewrite -I/-L on MSVC-like, drop IPO and
#         every -fuse-ld= / -flto* / -ffat-lto-objects / -fno-fat-lto-objects.
# Pass 2: IPO tokens of this profile according to the resolved mode
#         (inherit parent / on / off / fat).
#         CMake leaves keep CMAKE_INTERPROCEDURAL_OPTIMIZATION. Do not put
#         -flto / -ffat-lto-objects back on C/CXX: the child's IPO module
#         would then append -flto=auto -fno-fat-lto-objects and the last
#         token wins. Fat is expressed as CMAKE_<LANG>_COMPILE_OPTIONS_IPO
#         (`BM_TC_IPO_COMPILE_OPTIONS`) so the module and BM agree.
#         LD still gets -flto (or /LTCG) so the link line is LTO.
#         AppleClang rejects -ffat-lto-objects; Darwin clang fat → on
#         (-flto) + STATUS once. Homebrew gcc on Darwin keeps fat on the
#         IPO compile-options string.
#         MSVC and clang-cl treat fat as on (/GL+/LTCG or -flto).
# Pass 3: -fuse-ld= of this profile only (gcc=bfd, clang/clang-cl=lld,
#         msvc=none). Always, not only when IPO is on.
#         clang-cl Meson sanity puts link_args after /link; the driver
#         only honors -fuse-ld= on the compiler command. Put it on
#         C/CXX as well as LD.
#         Darwin gcc/clang: no -fuse-ld (ld64).
# Pass 4: GNU rescan wrap tokens for later CMAKE_<LANG>_LINK_EXECUTABLE
#         (`BM_TC_LINK_GROUP_START` / `BM_TC_LINK_GROUP_END`).
#         Linux gcc/clang only. Empty on Darwin, MSVC, clang-cl.

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

## @brief Parent-scope IPO: cache flags or leftover tokens in the strings.
## @param[in]  c_str   C flags.
## @param[in]  cxx_str CXX flags.
## @param[in]  ld_str  LD flags.
## @param[out] out_var TRUE if the parent wants IPO.
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
			if(_s MATCHES "(^| )(-flto|/GL|/LTCG|-fwhole-program-vtables|-ffat-lto-objects)( |$)")
				set(_yes TRUE)
				break()
			endif()
		endforeach()
	endif()
	set(${out_var} "${_yes}" PARENT_SCOPE)
endfunction()

## @brief Resolve `inherit|on|off|fat` against the parent.
## @param[in]  mode    From `_bm_opt_parse_ipo` (`inherit` if the key is absent).
## @param[in]  c_str   C flags (used only when mode is inherit).
## @param[in]  cxx_str CXX flags.
## @param[in]  ld_str  LD flags.
## @param[out] out_on  TRUE when thin or fat LTO tokens must be written.
## @param[out] out_fat TRUE when the caller may write `-ffat-lto-objects`.
## @note This function does not look at APPLE or the profile. Darwin
##       AppleClang demotion happens in `_bm_tc_translate_flags`.
## @note MSVC/clang-cl never consume out_fat; the caller treats fat as on
##       for those profiles.
function(_bm_tc_ipo_resolve mode c_str cxx_str ld_str out_on out_fat)
	set(_on FALSE)
	set(_fat FALSE)
	if("${mode}" STREQUAL "off")
		set(_on FALSE)
	elseif("${mode}" STREQUAL "on")
		set(_on TRUE)
	elseif("${mode}" STREQUAL "fat")
		set(_on TRUE)
		set(_fat TRUE)
	else()
		_bm_tc_ipo_wanted("${c_str}" "${cxx_str}" "${ld_str}" _on)
	endif()
	set(${out_on} "${_on}" PARENT_SCOPE)
	set(${out_fat} "${_fat}" PARENT_SCOPE)
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
## @note Also drops `-fno-fat-lto-objects` and `-flto=auto` so a child
##       IPO module cannot leak a second dialect into CMAKE_C_FLAGS.
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
				OR _t STREQUAL "-ffat-lto-objects"
				OR _t STREQUAL "-fno-fat-lto-objects"
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
## @param[in]     ARGN    Optional IPO mode from `_bm_opt_parse_ipo`
##            (`inherit`, `on`, `off`, `fat`). Omitted → `inherit`.
## @note Linux gcc: `-fuse-ld=bfd` on LD only.
##       Linux clang: `-fuse-ld=lld` on LD only.
##       Darwin gcc/clang: no `-fuse-ld` (ld64; CMake rejects BFD / APPLE).
##       clang-cl: `-fuse-ld=lld` on C/CXX and LD (Meson `/link` order).
## @note Unix gcc/clang IPO compile tokens go to `BM_TC_IPO_COMPILE_OPTIONS`,
##       not back into C/CXX flags. `BM_TC_IPO_ON` / `BM_TC_IPO_FAT` follow.
## @note GNU rescan: `BM_TC_LINK_GROUP_START`=`-Wl,--start-group` and
##       `BM_TC_LINK_GROUP_END`=`-Wl,--end-group` on Linux gcc/clang.
##       Empty on Darwin / msvc / clang-cl (ld64 and link.exe do not
##       accept those flags; MSVC scans archives).
function(_bm_tc_translate_flags c_var cxx_var ld_var profile)
	set(_ipo_mode "inherit")
	if(ARGC GREATER 4)
		set(_ipo_mode "${ARGV4}")
	endif()
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Entering _bm_tc_translate_flags(${profile} ipo=${_ipo_mode})")
	set(_c "${${c_var}}")
	set(_cxx "${${cxx_var}}")
	set(_ld "${${ld_var}}")

	_bm_tc_ipo_resolve("${_ipo_mode}" "${_c}" "${_cxx}" "${_ld}" _ipo _fat)
	_bm_tc_sanitize_flag_string("${_c}" "${profile}" _c)
	_bm_tc_sanitize_flag_string("${_cxx}" "${profile}" _cxx)
	_bm_tc_sanitize_flag_string("${_ld}" "${profile}" _ld)

	set(_ipo_copt "")
	if(_ipo)
		if(profile STREQUAL "msvc")
			_bm_tc_flag_append(_c "/GL")
			_bm_tc_flag_append(_cxx "/GL")
			_bm_tc_flag_append(_ld "/LTCG")
		elseif(profile STREQUAL "clang-cl")
			_bm_tc_flag_append(_c "-flto")
			_bm_tc_flag_append(_cxx "-flto")
			_bm_tc_flag_append(_ld "-flto")
		else()
			_bm_tc_flag_append(_ld "-flto")
			if(_fat AND profile STREQUAL "clang" AND APPLE)
				get_property(_said GLOBAL PROPERTY BUILDMASTER_TC_IPO_FAT_DARWIN_NOTIFIED)
				if(NOT _said)
					_bm_log_message(TOOLCHAIN STATUS
						"IPO=fat ignored on Darwin: AppleClang has no -ffat-lto-objects; using IPO=on (-flto only). Further components will not be notified.")
					set_property(GLOBAL PROPERTY BUILDMASTER_TC_IPO_FAT_DARWIN_NOTIFIED TRUE)
				endif()
				set(_fat FALSE)
			endif()
			if(_fat AND (profile STREQUAL "gcc" OR profile STREQUAL "clang"))
				set(_ipo_copt "-flto -ffat-lto-objects")
			else()
				set(_ipo_copt "-flto")
			endif()
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

	set(_grp_s "")
	set(_grp_e "")
	if((profile STREQUAL "gcc" OR profile STREQUAL "clang") AND NOT APPLE)
		set(_grp_s "-Wl,--start-group")
		set(_grp_e "-Wl,--end-group")
	endif()

	set(${c_var} "${_c}" PARENT_SCOPE)
	set(${cxx_var} "${_cxx}" PARENT_SCOPE)
	set(${ld_var} "${_ld}" PARENT_SCOPE)
	set(BM_TC_IPO_ON "${_ipo}" PARENT_SCOPE)
	set(BM_TC_IPO_FAT "${_fat}" PARENT_SCOPE)
	set(BM_TC_IPO_COMPILE_OPTIONS "${_ipo_copt}" PARENT_SCOPE)
	set(BM_TC_LINK_GROUP_START "${_grp_s}" PARENT_SCOPE)
	set(BM_TC_LINK_GROUP_END "${_grp_e}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN DEBUG
		"translate ${profile} ipo=${_ipo_mode} on=${_ipo} fat=${_fat} copt='${_ipo_copt}' c='${_c}' ld='${_ld}'")
	_bm_log_message(TOOLCHAIN LOWLEVEL "Exiting _bm_tc_translate_flags")
endfunction()

## @brief Translate C/CXX/LD for one registered component.
## @param[in]     id      Component id (`BUILDMASTER_COMPONENT_<id>_OPTSTR`).
## @param[in,out] c_var   Name of the C flags variable.
## @param[in,out] cxx_var Name of the CXX flags variable.
## @param[in,out] ld_var  Name of the linker flags variable.
## @param[in]     profile gcc|clang|clang-cl|msvc
## @note Reads `IPO` from that component's OPTSTR via `_bm_opt_parse_ipo`.
##       `inherit` (key absent) uses parent
##       `CMAKE_INTERPROCEDURAL_OPTIMIZATION[_<CONFIG>]` and leftover
##       flto/GL tokens. `on` / `off` / `fat` override the parent.
##       A meta that stamped `IPO=` into OPTSTR is visible here.
## @note Delegates to `_bm_tc_translate_flags`. Callers that have no
##       component id keep calling that function (5th arg optional).
function(_bm_tc_translate_component id c_var cxx_var ld_var profile)
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Entering _bm_tc_translate_component(${id} ${profile})")
	get_property(_optstr GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTSTR)
	_bm_opt_parse_ipo("${_optstr}" _ipo_mode)
	_bm_tc_translate_flags("${c_var}" "${cxx_var}" "${ld_var}"
		"${profile}" "${_ipo_mode}")
	set(${c_var} "${${c_var}}" PARENT_SCOPE)
	set(${cxx_var} "${${cxx_var}}" PARENT_SCOPE)
	set(${ld_var} "${${ld_var}}" PARENT_SCOPE)
	set(BM_TC_IPO_ON "${BM_TC_IPO_ON}" PARENT_SCOPE)
	set(BM_TC_IPO_FAT "${BM_TC_IPO_FAT}" PARENT_SCOPE)
	set(BM_TC_IPO_COMPILE_OPTIONS "${BM_TC_IPO_COMPILE_OPTIONS}" PARENT_SCOPE)
	set(BM_TC_LINK_GROUP_START "${BM_TC_LINK_GROUP_START}" PARENT_SCOPE)
	set(BM_TC_LINK_GROUP_END "${BM_TC_LINK_GROUP_END}" PARENT_SCOPE)
	_bm_log_message(TOOLCHAIN LOWLEVEL
		"Exiting _bm_tc_translate_component")
endfunction()
