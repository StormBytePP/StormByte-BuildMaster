cmake_minimum_required(VERSION 3.28)
project(StormByte-Buffer C)

if(NOT COMMAND buildmaster_component)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "buffer fixture: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../logger" "${CMAKE_CURRENT_BINARY_DIR}/logger")

buildmaster_component(
	StormByte-Buffer
	"StormByte Suite - Buffer"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
	""
	static
	"StormByte-Buffer"
	"ALIAS=StormByte::Buffer"
)

buildmaster_depend(StormByte-Buffer StormByte-Logger)
buildmaster_link(StormByte-Buffer StormByte-Logger)
