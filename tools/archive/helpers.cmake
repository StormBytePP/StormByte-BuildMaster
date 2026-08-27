# =============================================================================
# tools/archive/helpers.cmake — static archiver resolution (shared)
# =============================================================================
# Usable from configure-time helpers and from cmake -P scripts (pass
# BUILDMASTER_SRCDIR and include this file).

if(DEFINED BUILDMASTER_SRCDIR AND EXISTS "${BUILDMASTER_SRCDIR}/log.cmake")
	include("${BUILDMASTER_SRCDIR}/log.cmake")
elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
	include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
endif()
if(COMMAND buildmaster_loglevel_init)
	buildmaster_loglevel_init()
endif()

## @brief Resolve the static archiver for this toolchain/host.
## @param[out] out_path  Absolute path to the tool (parent scope).
## @param[out] out_style Parent-scope `msvc_lib` (lib.exe / llvm-lib, /OUT:)
##            or `gnu_ar` (ar / llvm-ar / gcc-ar, MRI -M).
## @param[in]  hint      Optional extra name or absolute path (tried after
##            CMAKE_AR and ENV{AR}).
## @note Search order:
##       1. CMAKE_AR
##       2. ENV{AR}
##       3. hint (if non-empty)
##       4. Windows: llvm-lib, lib, lib.exe
##       5. else: llvm-ar, gcc-ar, ar
## @note Style is derived from the resolved binary name.
function(buildmaster_find_archiver out_path out_style)
	buildmaster_message(ARCHIVE LOWLEVEL "Entering buildmaster_find_archiver")
	if(ARGC GREATER 2)
		set(_hint "${ARGV2}")
	else()
		set(_hint "")
	endif()

	set(_candidates "")

	if(CMAKE_AR AND NOT CMAKE_AR STREQUAL "")
		list(APPEND _candidates "${CMAKE_AR}")
	endif()
	if(DEFINED ENV{AR} AND NOT "$ENV{AR}" STREQUAL "")
		list(APPEND _candidates "$ENV{AR}")
	endif()
	if(NOT _hint STREQUAL "")
		list(APPEND _candidates "${_hint}")
	endif()

	if(WIN32)
		list(APPEND _candidates llvm-lib lib lib.exe)
	else()
		list(APPEND _candidates llvm-ar gcc-ar ar)
	endif()

	set(_found "")
	foreach(_c IN LISTS _candidates)
		if(_c STREQUAL "")
			continue()
		endif()
		if(IS_ABSOLUTE "${_c}" AND EXISTS "${_c}")
			set(_found "${_c}")
			break()
		endif()
		find_program(_bm_ar_prog NAMES "${_c}")
		if(_bm_ar_prog)
			set(_found "${_bm_ar_prog}")
			break()
		endif()
		unset(_bm_ar_prog CACHE)
	endforeach()

	if(_found STREQUAL "")
		buildmaster_message(ARCHIVE FATAL
			"buildmaster_find_archiver: no archiver found (CMAKE_AR, ENV{AR}, llvm-lib/lib, llvm-ar/gcc-ar/ar)")
	endif()

	get_filename_component(_name "${_found}" NAME)
	string(TOLOWER "${_name}" _name_l)

	set(_style "gnu_ar")
	if(_name_l MATCHES "llvm-lib" OR _name_l STREQUAL "lib"
			OR _name_l MATCHES "lib\\.exe$")
		set(_style "msvc_lib")
	endif()

	buildmaster_message(ARCHIVE DEBUG "archiver=${_found} style=${_style}")
	set(${out_path} "${_found}" PARENT_SCOPE)
	set(${out_style} "${_style}" PARENT_SCOPE)
	buildmaster_message(ARCHIVE LOWLEVEL "Exiting buildmaster_find_archiver")
endfunction()
