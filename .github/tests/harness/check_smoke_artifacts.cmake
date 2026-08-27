# cmake -DBUILDMASTER_INSTALL_DIR=... -DBM_TEST_EXPECTED_DIR=...
#      -DBM_INSTALL_LIBDIR=... -DBM_INSTALL_INCLUDEDIR=... -P check_smoke_artifacts.cmake
#
# smoke_artifacts.txt lines:  path|platform
#   path may use <lib> / <include>
#   optional leading '!' means the path must NOT exist under the install prefix
#   platform: all | unix | windows
# Blank lines and lines whose first non-whitespace is '#' are ignored.

include("${CMAKE_CURRENT_LIST_DIR}/../../../log.cmake")
if(COMMAND buildmaster_loglevel_init)
	buildmaster_loglevel_init()
endif()

if(NOT BUILDMASTER_INSTALL_DIR)
	buildmaster_message(CORE FATAL "BUILDMASTER_INSTALL_DIR is required")
endif()
if(NOT BM_TEST_EXPECTED_DIR)
	buildmaster_message(CORE FATAL "BM_TEST_EXPECTED_DIR is required")
endif()

if(NOT BM_INSTALL_LIBDIR)
	set(BM_INSTALL_LIBDIR "lib")
endif()
if(NOT BM_INSTALL_INCLUDEDIR)
	set(BM_INSTALL_INCLUDEDIR "include")
endif()

set(_bm_art_list "${BM_TEST_EXPECTED_DIR}/smoke_artifacts.txt")
if(NOT EXISTS "${_bm_art_list}")
	buildmaster_message(CORE FATAL "Missing ${_bm_art_list}")
endif()

if(WIN32)
	set(_bm_plat windows)
else()
	set(_bm_plat unix)
endif()

set(_bm_fail FALSE)
set(_bm_ok 0)
set(_bm_absent_ok 0)

file(STRINGS "${_bm_art_list}" _bm_lines)
foreach(_line IN LISTS _bm_lines)
	string(STRIP "${_line}" _line)
	if(_line STREQUAL "")
		continue()
	endif()
	# Comments: first non-whitespace character is '#'
	if(_line MATCHES "^#")
		continue()
	endif()

	# Strict entry form: [!]path|all|unix|windows
	if(NOT _line MATCHES "^!?[^|]+\\|(all|unix|windows)$")
		buildmaster_message(CORE WARNING "Malformed artifact line: ${_line}")
		continue()
	endif()

	string(REPLACE "|" ";" _parts "${_line}")
	list(GET _parts 0 _rel)
	list(GET _parts 1 _scope)
	if(NOT _scope STREQUAL "all" AND NOT _scope STREQUAL "${_bm_plat}")
		continue()
	endif()

	set(_absent FALSE)
	if(_rel MATCHES "^!")
		set(_absent TRUE)
		string(SUBSTRING "${_rel}" 1 -1 _rel)
	endif()

	string(REPLACE "<lib>" "${BM_INSTALL_LIBDIR}" _rel "${_rel}")
	string(REPLACE "<include>" "${BM_INSTALL_INCLUDEDIR}" _rel "${_rel}")

	set(_full "${BUILDMASTER_INSTALL_DIR}/${_rel}")
	if(_absent)
		if(EXISTS "${_full}")
			buildmaster_message(CORE WARNING "Smoke artifact must not exist: ${_full}")
			set(_bm_fail TRUE)
		else()
			math(EXPR _bm_absent_ok "${_bm_absent_ok} + 1")
		endif()
	else()
		if(NOT EXISTS "${_full}")
			buildmaster_message(CORE WARNING "Smoke artifact missing: ${_full}")
			set(_bm_fail TRUE)
		else()
			math(EXPR _bm_ok "${_bm_ok} + 1")
		endif()
	endif()
endforeach()

if(_bm_fail)
	buildmaster_message(CORE FATAL "BuildMaster smoke artifact checks failed")
endif()

buildmaster_message(CORE STATUS
	"smoke artifacts: OK (${_bm_ok} present, ${_bm_absent_ok} expected absent)")
