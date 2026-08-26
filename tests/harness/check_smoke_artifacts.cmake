# cmake -DBUILDMASTER_INSTALL_DIR=... -DBM_TEST_EXPECTED_DIR=...
#      -DBM_INSTALL_LIBDIR=... -DBM_INSTALL_INCLUDEDIR=... -P check_smoke_artifacts.cmake

if(NOT BUILDMASTER_INSTALL_DIR)
	message(FATAL_ERROR "BUILDMASTER_INSTALL_DIR is required")
endif()
if(NOT BM_TEST_EXPECTED_DIR)
	message(FATAL_ERROR "BM_TEST_EXPECTED_DIR is required")
endif()

if(NOT BM_INSTALL_LIBDIR)
	set(BM_INSTALL_LIBDIR "lib")
endif()
if(NOT BM_INSTALL_INCLUDEDIR)
	set(BM_INSTALL_INCLUDEDIR "include")
endif()

set(_bm_art_list "${BM_TEST_EXPECTED_DIR}/smoke_artifacts.txt")
if(NOT EXISTS "${_bm_art_list}")
	message(FATAL_ERROR "Missing ${_bm_art_list}")
endif()

if(WIN32)
	set(_bm_plat windows)
else()
	set(_bm_plat unix)
endif()

set(_bm_fail FALSE)
set(_bm_ok 0)

file(STRINGS "${_bm_art_list}" _bm_lines)
foreach(_line IN LISTS _bm_lines)
	string(STRIP "${_line}" _line)
	if(_line STREQUAL "" OR _line MATCHES "^#")
		continue()
	endif()

	string(REPLACE "|" ";" _parts "${_line}")
	list(LENGTH _parts _n)
	if(_n LESS 2)
		message(WARNING "Malformed artifact line: ${_line}")
		continue()
	endif()
	list(GET _parts 0 _rel)
	list(GET _parts 1 _scope)
	if(NOT _scope STREQUAL "all" AND NOT _scope STREQUAL "${_bm_plat}")
		continue()
	endif()

	string(REPLACE "<lib>" "${BM_INSTALL_LIBDIR}" _rel "${_rel}")
	string(REPLACE "<include>" "${BM_INSTALL_INCLUDEDIR}" _rel "${_rel}")

	set(_full "${BUILDMASTER_INSTALL_DIR}/${_rel}")
	if(NOT EXISTS "${_full}")
		message(SEND_ERROR "Smoke artifact missing: ${_full}")
		set(_bm_fail TRUE)
	else()
		math(EXPR _bm_ok "${_bm_ok} + 1")
	endif()
endforeach()

if(_bm_fail)
	message(FATAL_ERROR "BuildMaster smoke artifact checks failed")
endif()

message(STATUS "BuildMaster smoke artifacts: OK (${_bm_ok} found)")
