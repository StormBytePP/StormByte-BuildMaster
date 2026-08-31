cmake_minimum_required(VERSION 3.28)
project(SharedLogger C)

if(NOT COMMAND buildmaster_component)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "logger fixture: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../base"
	"${CMAKE_CURRENT_BINARY_DIR}/base")

buildmaster_component(
	SharedLogger
	"Harness Shared Logger"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
	""
	shared
	"SharedLogger"
	"ALIAS=Shared::Logger"
)

buildmaster_depend(SharedLogger SharedBase)
buildmaster_link(SharedLogger SharedBase)
