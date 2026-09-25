# Upstream cmake_minimum_required is illegal. The patch makes it legal.
# The second install must take the stamp hit and leave the worktree upstream.

_bm_tools_demand_named(git)
if(NOT GIT_EXECUTABLE)
	message(FATAL_ERROR "stamp-patch: GIT_EXECUTABLE not set")
endif()

set(_repo "${CMAKE_CURRENT_BINARY_DIR}/repo")
if(NOT EXISTS "${_repo}/.git")
	file(MAKE_DIRECTORY "${_repo}")
	execute_process(
		COMMAND "${GIT_EXECUTABLE}" init
		WORKING_DIRECTORY "${_repo}"
		RESULT_VARIABLE _rc
	)
	if(NOT _rc EQUAL 0)
		message(FATAL_ERROR "stamp-patch: git init failed")
	endif()
	file(WRITE "${_repo}/stampleaf.h" "#pragma once\nint stampleaf_id(void);\n")
	file(WRITE "${_repo}/stampleaf.c" "int stampleaf_id(void) { return 1; }\n")
	file(WRITE "${_repo}/CMakeLists.txt"
"cmake_minimum_required(VERSION 99.0)
project(stampleaf LANGUAGES C)
include(GNUInstallDirs)
add_library(stampleaf STATIC stampleaf.c)
target_include_directories(stampleaf PUBLIC
	\$<BUILD_INTERFACE:\${CMAKE_CURRENT_SOURCE_DIR}>
	\$<INSTALL_INTERFACE:\${CMAKE_INSTALL_INCLUDEDIR}>
)
install(TARGETS stampleaf
	ARCHIVE DESTINATION \${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION \${CMAKE_INSTALL_LIBDIR}
)
install(FILES stampleaf.h DESTINATION \${CMAKE_INSTALL_INCLUDEDIR})
")
	execute_process(
		COMMAND "${GIT_EXECUTABLE}" add CMakeLists.txt stampleaf.c stampleaf.h
		WORKING_DIRECTORY "${_repo}"
		RESULT_VARIABLE _rc
	)
	if(NOT _rc EQUAL 0)
		message(FATAL_ERROR "stamp-patch: git add failed")
	endif()
	execute_process(
		COMMAND "${GIT_EXECUTABLE}" -c user.email=bm@test -c user.name=BM
			commit -m seed
		WORKING_DIRECTORY "${_repo}"
		RESULT_VARIABLE _rc
	)
	if(NOT _rc EQUAL 0)
		message(FATAL_ERROR "stamp-patch: git commit failed")
	endif()
endif()

execute_process(
	COMMAND "${GIT_EXECUTABLE}" reset --hard
	WORKING_DIRECTORY "${_repo}"
	RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
	message(FATAL_ERROR "stamp-patch: git reset before diff failed")
endif()
file(READ "${_repo}/CMakeLists.txt" _upstream)
string(REPLACE "VERSION 99.0" "VERSION 3.20" _patched "${_upstream}")
if(_patched STREQUAL _upstream)
	message(FATAL_ERROR "stamp-patch: upstream CMakeLists has no VERSION 99.0")
endif()
file(WRITE "${_repo}/CMakeLists.txt" "${_patched}")
set(_patch "${CMAKE_CURRENT_BINARY_DIR}/fix-minimum.patch")
execute_process(
	COMMAND "${GIT_EXECUTABLE}" diff -- CMakeLists.txt
	WORKING_DIRECTORY "${_repo}"
	OUTPUT_FILE "${_patch}"
	RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
	message(FATAL_ERROR "stamp-patch: git diff failed")
endif()
execute_process(
	COMMAND "${GIT_EXECUTABLE}" reset --hard
	WORKING_DIRECTORY "${_repo}"
	RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
	message(FATAL_ERROR "stamp-patch: git reset after diff failed")
endif()

_bm_backend_cmake_create(
	stamp-leaf
	"Stamp leaf"
	"${_repo}"
	""
	static
	"stampleaf"
	"GIT={PATCH=${_patch}}"
)
get_property(_bd GLOBAL PROPERTY BUILDMASTER_COMPONENT_stamp-leaf_BUILDDIR)
set_property(GLOBAL PROPERTY STAMP_PATCH_REPO "${_repo}")
set_property(GLOBAL PROPERTY STAMP_PATCH_BUILDDIR "${_bd}")
