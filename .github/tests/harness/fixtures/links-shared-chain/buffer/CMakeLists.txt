cmake_minimum_required(VERSION 3.28)
project(SharedBuffer-wrapper C)

if(NOT COMMAND buildmaster_component)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "buffer wrapper: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

buildmaster_component(
	SharedBuffer
	"Harness Shared Buffer"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
	""
	shared
	"SharedBuffer"
	"ALIAS=Shared::Buffer"
)

buildmaster_link(SharedBuffer SharedLogger)
