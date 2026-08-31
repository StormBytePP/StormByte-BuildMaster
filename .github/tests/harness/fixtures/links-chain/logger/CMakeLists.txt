cmake_minimum_required(VERSION 3.28)
project(StormByte-Logger C)

if(NOT COMMAND buildmaster_component)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "logger fixture: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../base" "${CMAKE_CURRENT_BINARY_DIR}/base")

buildmaster_component(
	StormByte-Logger
	"StormByte Suite - Logger"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
	""
	static
	"StormByte-Logger"
	"ALIAS=StormByte::Logger"
)

buildmaster_depend(StormByte-Logger StormByte-Base)
buildmaster_link(StormByte-Logger StormByte-Base)
