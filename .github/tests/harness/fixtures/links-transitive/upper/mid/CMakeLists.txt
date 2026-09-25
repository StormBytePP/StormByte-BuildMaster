cmake_minimum_required(VERSION 3.28)
project(TransMid-wrapper C)

if(NOT COMMAND buildmaster_component)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "trans mid wrapper: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/base"
	"${CMAKE_CURRENT_BINARY_DIR}/base")

buildmaster_component(
	TransMid
	"Harness transitive mid"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
	""
	shared
	"TransMid"
)

buildmaster_depend(TransMid TransBase)
buildmaster_link(TransMid TransBase)

# Upper is the real shared library in this process, not a BM id.
# Name only Mid. Base has to arrive through Mid's links file.
buildmaster_link(TransUpper TransMid)
