cmake_minimum_required(VERSION 3.28)
project(RaceBase-wrapper C)

if(NOT COMMAND buildmaster_component)
	if(NOT DEFINED BUILDMASTER_ROOT OR BUILDMASTER_ROOT STREQUAL "")
		message(FATAL_ERROR "race base wrapper: BUILDMASTER_ROOT is empty")
	endif()
	include("${BUILDMASTER_ROOT}/helpers.cmake")
endif()

buildmaster_component(
	RaceBase
	"Harness race base"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
	""
	shared
	"RaceBase"
)
