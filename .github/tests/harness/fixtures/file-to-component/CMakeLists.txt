# file_decompress then component_dependency on the unpack target.

set(_pack_src "${CMAKE_CURRENT_BINARY_DIR}/pack_src")
set(_archive "${CMAKE_CURRENT_BINARY_DIR}/payload.tar.gz")
set(_extract "${CMAKE_CURRENT_BINARY_DIR}/payload")

file(MAKE_DIRECTORY "${_pack_src}")
file(WRITE "${_pack_src}/payload_mark.h"
	"#ifndef PAYLOAD_MARK_H\n#define PAYLOAD_MARK_H\n#define PAYLOAD_MARK 9\n#endif\n")

execute_process(
	COMMAND ${CMAKE_COMMAND} -E tar czf "${_archive}" "payload_mark.h"
	WORKING_DIRECTORY "${_pack_src}"
	RESULT_VARIABLE _tar_rc
)
if(NOT _tar_rc EQUAL 0)
	message(FATAL_ERROR "file-to-component: tar failed")
endif()

file_decompress(payload_unpack
	"${_archive}"
	"${_extract}"
	TITLE "Harness payload"
)

ensure_build_dir(PAYLOAD_LIB_BUILD "payload-lib")
create_cmake_component(
	payload-lib
	"Harness file-to-component library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${PAYLOAD_LIB_BUILD}"
	"-DPAYLOAD_INCLUDE_DIR=${_extract}"
	static
	"payloadlib"
)
component_dependency(payload-lib payload_unpack)