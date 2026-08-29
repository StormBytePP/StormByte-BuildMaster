# cmake -DOUTPUT=... -DINPUTS=a.a,b.a -DBUILDMASTER_SRCDIR=... [-DCMAKE_AR=...] -P merge_static_archives.cmake
# INPUTS is comma-separated.

if(NOT BUILDMASTER_SRCDIR)
	get_filename_component(_here "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)
	get_filename_component(BUILDMASTER_SRCDIR "${_here}" DIRECTORY)
endif()

include("${BUILDMASTER_SRCDIR}/log.cmake")
if(COMMAND buildmaster_loglevel_init)
	buildmaster_loglevel_init()
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

include("${BUILDMASTER_SRCDIR}/tools/archive/helpers.cmake")
buildmaster_find_archiver(_ar _style)

# Apple ar has no MRI (-M). Prefer libtool -static.
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
	_bm_log_message(BUNDLE INFO "merged ${OUTPUT} (${_inputs}) with libtool -static")
	return()
endif()

if(_style STREQUAL "msvc_lib")
	execute_process(
		COMMAND "${_ar}" /NOLOGO "/OUT:${OUTPUT}" ${_inputs}
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		_bm_log_message(BUNDLE FATAL "merge_static_archives: ${_ar} /OUT failed (${_rc}): ${_err}")
	endif()
	_bm_log_message(BUNDLE INFO "merged ${OUTPUT} with ${_ar} (msvc_lib)")
	return()
endif()

# GNU / LLVM ar MRI
set(_mri "${OUTPUT}.mri")
set(_mri_txt "CREATE ${OUTPUT}\n")
foreach(_in IN LISTS _inputs)
	string(APPEND _mri_txt "ADDLIB ${_in}\n")
endforeach()
string(APPEND _mri_txt "SAVE\nEND\n")
file(WRITE "${_mri}" "${_mri_txt}")

execute_process(
	COMMAND "${_ar}" -M
	INPUT_FILE "${_mri}"
	RESULT_VARIABLE _rc
	OUTPUT_VARIABLE _out
	ERROR_VARIABLE _err
)
file(REMOVE "${_mri}")
if(NOT _rc EQUAL 0)
	_bm_log_message(BUNDLE FATAL "merge_static_archives: ar -M failed (${_rc}): ${_err}")
endif()
_bm_log_message(BUNDLE INFO "merged ${OUTPUT} with ${_ar} (gnu_ar)")
