# cmake -DOUTPUT=... -DINPUTS=<path>;<path>;...
#      -DBUILDMASTER_SRCDIR=... [-DCMAKE_AR=...] [-DAR=...]
#      -P merge_static_archives.cmake
#
# Merge static archives into one canonical OUTPUT.
# Archiver: buildmaster_find_archiver (CMAKE_AR, ENV{AR}, then platform tools).

if(NOT OUTPUT)
	message(FATAL_ERROR "merge_static_archives: need -DOUTPUT=")
endif()
if(NOT INPUTS)
	message(FATAL_ERROR "merge_static_archives: need -DINPUTS=")
endif()
if(NOT BUILDMASTER_SRCDIR)
	message(FATAL_ERROR "merge_static_archives: need -DBUILDMASTER_SRCDIR=")
endif()

include("${BUILDMASTER_SRCDIR}/tools/archive/helpers.cmake")

string(REPLACE "," ";" _inputs "${INPUTS}")
set(_files "")
foreach(_in IN LISTS _inputs)
	string(STRIP "${_in}" _in)
	if(_in STREQUAL "")
		continue()
	endif()
	if(NOT EXISTS "${_in}")
		message(FATAL_ERROR
			"merge_static_archives: input missing: ${_in}")
	endif()
	list(APPEND _files "${_in}")
endforeach()

if(_files STREQUAL "")
	message(FATAL_ERROR "merge_static_archives: no input files")
endif()

get_filename_component(_out_dir "${OUTPUT}" DIRECTORY)
if(NOT _out_dir STREQUAL "")
	file(MAKE_DIRECTORY "${_out_dir}")
endif()

if(EXISTS "${OUTPUT}")
	file(REMOVE "${OUTPUT}")
endif()

# Prefer -DAR= as hint after CMAKE_AR / ENV{AR} inside the finder
set(_hint "")
if(AR AND NOT AR STREQUAL "")
	set(_hint "${AR}")
endif()

buildmaster_find_archiver(_ar _style "${_hint}")
get_filename_component(_ar_name "${_ar}" NAME)

if(_style STREQUAL "msvc_lib")
	execute_process(
		COMMAND "${_ar}" "/NOLOGO" "/OUT:${OUTPUT}" ${_files}
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		message(FATAL_ERROR
			"merge_static_archives: ${_ar_name} failed (${_rc}): ${_err}")
	endif()
elseif(_style STREQUAL "gnu_ar")
	set(_script "")
	string(APPEND _script "CREATE ${OUTPUT}\n")
	foreach(_f IN LISTS _files)
		string(APPEND _script "ADDLIB ${_f}\n")
	endforeach()
	string(APPEND _script "SAVE\nEND\n")
	set(_mri "${OUTPUT}.mri")
	file(WRITE "${_mri}" "${_script}")
	execute_process(
		COMMAND "${_ar}" -M
		INPUT_FILE "${_mri}"
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	file(REMOVE "${_mri}")
	if(NOT _rc EQUAL 0)
		message(FATAL_ERROR
			"merge_static_archives: ${_ar_name} -M failed (${_rc}): ${_err}")
	endif()
else()
	message(FATAL_ERROR
		"merge_static_archives: unknown style '${_style}'")
endif()

if(NOT EXISTS "${OUTPUT}")
	message(FATAL_ERROR
		"merge_static_archives: OUTPUT not created: ${OUTPUT}")
endif()

list(LENGTH _files _n)
message(STATUS "[BuildMaster] merged ${OUTPUT} (${_n} inputs) with ${_ar_name} (${_style})")
