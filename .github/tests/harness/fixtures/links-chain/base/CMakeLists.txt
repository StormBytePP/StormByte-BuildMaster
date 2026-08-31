cmake_minimum_required(VERSION 3.28)
project(StormByte-Base C)

if(NOT COMMAND buildmaster_component)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "base fixture: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

buildmaster_component(
	StormByte-Base
	"StormByte Suite - Base"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
	""
	static
	"StormByte-Base"
	"ALIAS=StormByte::Base"
)
