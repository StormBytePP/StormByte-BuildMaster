# =============================================================================
# component/archive/find_archiver.cmake — static archiver resolution (shared)
# =============================================================================

## @brief Resolve the static archiver for this toolchain/host.
## @param[out] out_path  Absolute path to the tool (parent scope).
## @param[out] out_style Parent-scope `msvc_lib` (`lib.exe` / `llvm-lib`, `/OUT:`)
##            or `gnu_ar` (`ar` / `llvm-ar` / `gcc-ar`, MRI `-M`).
## @param[in]  hint      Optional extra name or absolute path (tried after
##            `CMAKE_AR` and `ENV{AR}`). Passed as ARGV2 when present.
## @note Search order:
##       1. `CMAKE_AR`
##       2. `ENV{AR}`
##       3. `hint` (if non-empty)
##       4. Windows: `llvm-lib`, `lib`, `lib.exe`
##       5. else: `llvm-ar`, `gcc-ar`, `ar`
## @note Style is derived from the resolved binary name (`llvm-lib` / `lib` /
##       `lib.exe` → `msvc_lib`; everything else → `gnu_ar`).
## @note Missing archiver is fatal (`_bm_log_message(ARCHIVE FATAL …)`).
## @note Safe to include from `cmake -P` scripts after `log.cmake` (the archive
##       helpers stub already does that).
function(_bm_component_archive_find out_path out_style)
	_bm_log_message(ARCHIVE LOWLEVEL "Entering _bm_component_archive_find")
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
		_bm_log_message(ARCHIVE FATAL
			"_bm_component_archive_find: no archiver found (CMAKE_AR, ENV{AR}, llvm-lib/lib, llvm-ar/gcc-ar/ar)")
	endif()

	get_filename_component(_name "${_found}" NAME)
	string(TOLOWER "${_name}" _name_l)

	set(_style "gnu_ar")
	if(_name_l MATCHES "llvm-lib" OR _name_l STREQUAL "lib"
			OR _name_l MATCHES "lib\\.exe$")
		set(_style "msvc_lib")
	endif()

	_bm_log_message(ARCHIVE DEBUG "archiver=${_found} style=${_style}")
	set(${out_path} "${_found}" PARENT_SCOPE)
	set(${out_style} "${_style}" PARENT_SCOPE)
	_bm_log_message(ARCHIVE LOWLEVEL "Exiting _bm_component_archive_find")
endfunction()
