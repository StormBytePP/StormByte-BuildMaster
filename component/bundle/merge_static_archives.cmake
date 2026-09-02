# cmake -DOUTPUT=... -DINPUTS=a.a,b.a -DBUILDMASTER_SRCDIR=... -DCMAKE_AR=... -P
# INPUTS is comma-separated.
# CMAKE_AR is the publisher profile archiver (lib.exe when TOOLCHAIN=msvc).

if(NOT BUILDMASTER_SRCDIR)
	get_filename_component(_here "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)
	get_filename_component(BUILDMASTER_SRCDIR "${_here}" DIRECTORY)
endif()

include("${BUILDMASTER_SRCDIR}/log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

if(NOT OUTPUT OR NOT INPUTS)
	_bm_log_message(BUNDLE FATAL "merge_static_archives: need -DOUTPUT= and -DINPUTS=")
endif()

string(REPLACE "," ";" _inputs "${INPUTS}")
if(NOT _inputs)
	_bm_log_message(BUNDLE FATAL "merge_static_archives: empty INPUTS")
endif()

foreach(_in IN LISTS _inputs)
	if(NOT EXISTS "${_in}")
		_bm_log_message(BUNDLE FATAL "merge_static_archives: missing input ${_in}")
	endif()
endforeach()

get_filename_component(_out_dir "${OUTPUT}" DIRECTORY)
file(MAKE_DIRECTORY "${_out_dir}")

if(NOT CMAKE_AR OR CMAKE_AR STREQUAL "")
	_bm_log_message(BUNDLE FATAL
		"merge_static_archives: -DCMAKE_AR= is required (toolchain profile AR)")
endif()
if(NOT EXISTS "${CMAKE_AR}")
	_bm_log_message(BUNDLE FATAL
		"merge_static_archives: CMAKE_AR missing: ${CMAKE_AR}")
endif()

get_filename_component(_ar_name "${CMAKE_AR}" NAME)
string(TOLOWER "${_ar_name}" _ar_l)
set(_style "gnu_ar")
if(_ar_l MATCHES "llvm-lib" OR _ar_l STREQUAL "lib" OR _ar_l MATCHES "lib\\.exe$")
	set(_style "msvc_lib")
endif()

if(APPLE)
	find_program(_libtool NAMES libtool)
	if(NOT _libtool)
		_bm_log_message(BUNDLE FATAL "merge_static_archives: libtool not found (needed on Apple)")
	endif()
	execute_process(
		COMMAND "${_libtool}" -static -o "${OUTPUT}" ${_inputs}
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		_bm_log_message(BUNDLE FATAL "merge_static_archives: libtool -static failed (${_rc}): ${_err}")
	endif()
	_bm_log_message(BUNDLE INFO "merged ${OUTPUT} with libtool -static")
	return()
endif()

if(_style STREQUAL "msvc_lib")
	execute_process(
		COMMAND "${CMAKE_AR}" /NOLOGO "/OUT:${OUTPUT}" ${_inputs}
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		_bm_log_message(BUNDLE FATAL "merge_static_archives: ${CMAKE_AR} /OUT failed (${_rc}): ${_err}")
	endif()
	_bm_log_message(BUNDLE INFO "merged ${OUTPUT} with ${CMAKE_AR} (msvc_lib)")
	return()
endif()

set(_mri "${OUTPUT}.mri")
set(_mri_txt "CREATE ${OUTPUT}\n")
foreach(_in IN LISTS _inputs)
	string(APPEND _mri_txt "ADDLIB ${_in}\n")
endforeach()
string(APPEND _mri_txt "SAVE\nEND\n")
file(WRITE "${_mri}" "${_mri_txt}")

execute_process(
	COMMAND "${CMAKE_AR}" -M
	INPUT_FILE "${_mri}"
	RESULT_VARIABLE _rc
	OUTPUT_VARIABLE _out
	ERROR_VARIABLE _err
)
file(REMOVE "${_mri}")
if(NOT _rc EQUAL 0)
	_bm_log_message(BUNDLE FATAL "merge_static_archives: ar -M failed (${_rc}): ${_err}")
endif()
_bm_log_message(BUNDLE INFO "merged ${OUTPUT} with ${CMAKE_AR} (gnu_ar)")
