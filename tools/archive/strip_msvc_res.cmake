# =============================================================================
# tools/archive/strip_msvc_res.cmake
# =============================================================================
# Function: buildmaster_strip_msvc_res(lib)
# Script:  cmake -DLIB=<archive.lib> -DBUILDMASTER_SRCDIR=<root>
#          [-DCMAKE_AR=…] -P tools/archive/strip_msvc_res.cmake
#
# After RENAME: list members of a static MSVC/clang-cl archive and
# /REMOVE every member whose basename ends in .res (case-insensitive).
# Missing archive, non-msvc_lib archiver, empty list, or already-stripped
# members are not fatal.
#
# This file is also included from tools/archive/helpers.cmake so install_exec
# and other -P scripts can call the function. Script-mode body MUST only run
# when *this* file is the -P entry point. CMAKE_SCRIPT_MODE_FILE is set for
# *any* cmake -P (e.g. merge_static_archives.cmake); comparing against
# CMAKE_CURRENT_LIST_FILE is the include-safe guard.

if(NOT COMMAND buildmaster_message)
	if(DEFINED BUILDMASTER_SRCDIR AND EXISTS "${BUILDMASTER_SRCDIR}/log.cmake")
		include("${BUILDMASTER_SRCDIR}/log.cmake")
	elseif(EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
		include("${CMAKE_CURRENT_LIST_DIR}/../../log.cmake")
	endif()
	if(COMMAND buildmaster_loglevel_init)
		buildmaster_loglevel_init()
	endif()
endif()

if(NOT COMMAND buildmaster_find_archiver)
	include("${CMAKE_CURRENT_LIST_DIR}/find_archiver.cmake")
endif()

## @brief Strip `*.res` members from one MSVC/clang-cl static archive.
## @param[in] lib Absolute path to the `.lib` (canonical name, post-RENAME).
## @note Resolves the archiver via `buildmaster_find_archiver`. If the style
##       is not `msvc_lib` (Unix `ar` / `llvm-ar`), this is a silent no-op.
## @note Lists members with `/LIST`. A member is removed only when its
##       basename matches `*.res` / `*.RES` (case-insensitive). Paths such
##       as `foo.dir\bar.res` are accepted; `.obj`, `.pdb`, and names that
##       merely contain `res` are not.
## @note `/REMOVE` uses the member string exactly as `/LIST` printed it.
## @note Missing `lib`, failed `/LIST`, or failed `/REMOVE` of one member
##       do not abort the parent install (`WARNING` / `DEBUG` only).
function(buildmaster_strip_msvc_res lib)
	buildmaster_message(ARCHIVE LOWLEVEL "Entering buildmaster_strip_msvc_res")
	if("${lib}" STREQUAL "")
		buildmaster_message(ARCHIVE FATAL "buildmaster_strip_msvc_res: empty lib path")
	endif()

	if(NOT EXISTS "${lib}")
		buildmaster_message(ARCHIVE DEBUG "strip_msvc_res: missing ${lib} (skip)")
		buildmaster_message(ARCHIVE LOWLEVEL "Exiting buildmaster_strip_msvc_res")
		return()
	endif()

	set(_hint "")
	if(DEFINED CMAKE_AR AND NOT CMAKE_AR STREQUAL "")
		set(_hint "${CMAKE_AR}")
	endif()
	buildmaster_find_archiver(_bm_ar _bm_style "${_hint}")
	if(NOT _bm_style STREQUAL "msvc_lib")
		buildmaster_message(ARCHIVE DEBUG
			"strip_msvc_res: archiver style '${_bm_style}' is not msvc_lib (skip)")
		buildmaster_message(ARCHIVE LOWLEVEL "Exiting buildmaster_strip_msvc_res")
		return()
	endif()

	execute_process(
		COMMAND "${_bm_ar}" /NOLOGO /LIST "${lib}"
		OUTPUT_VARIABLE _list
		ERROR_VARIABLE _err
		RESULT_VARIABLE _rc
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)
	if(NOT _rc EQUAL 0)
		buildmaster_message(ARCHIVE WARNING
			"strip_msvc_res: /LIST failed on ${lib} (${_rc}): ${_err}")
		buildmaster_message(ARCHIVE LOWLEVEL "Exiting buildmaster_strip_msvc_res")
		return()
	endif()

	string(REPLACE "\r\n" "\n" _list "${_list}")
	string(REPLACE "\r" "\n" _list "${_list}")
	string(REPLACE "\n" ";" _members "${_list}")

	set(_removed 0)
	foreach(_mem IN LISTS _members)
		string(STRIP "${_mem}" _mem)
		if(_mem STREQUAL "")
			continue()
		endif()
		get_filename_component(_bn "${_mem}" NAME)
		if(NOT _bn MATCHES "\\.[Rr][Ee][Ss]$")
			continue()
		endif()

		buildmaster_message(ARCHIVE INFO "strip_msvc_res: removing '${_mem}' from ${lib}")
		execute_process(
			COMMAND "${_bm_ar}" /NOLOGO "/REMOVE:${_mem}" "${lib}"
			RESULT_VARIABLE _rc2
			OUTPUT_VARIABLE _out2
			ERROR_VARIABLE _err2
		)
		if(NOT _rc2 EQUAL 0)
			buildmaster_message(ARCHIVE WARNING
				"strip_msvc_res: /REMOVE:${_mem} failed (${_rc2}): ${_err2}")
		else()
			math(EXPR _removed "${_removed} + 1")
		endif()
	endforeach()

	buildmaster_message(ARCHIVE DEBUG
		"strip_msvc_res: removed ${_removed} .res member(s) from ${lib}")
	buildmaster_message(ARCHIVE LOWLEVEL "Exiting buildmaster_strip_msvc_res")
endfunction()

if(CMAKE_SCRIPT_MODE_FILE AND CMAKE_SCRIPT_MODE_FILE STREQUAL CMAKE_CURRENT_LIST_FILE)
	if(NOT LIB)
		if(COMMAND buildmaster_message)
			buildmaster_message(ARCHIVE FATAL "strip_msvc_res: need -DLIB=")
		else()
			message(FATAL_ERROR "strip_msvc_res: need -DLIB=")
		endif()
	endif()
	buildmaster_strip_msvc_res("${LIB}")
endif()
