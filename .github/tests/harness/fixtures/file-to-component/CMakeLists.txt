# FILES unpack before configure: payload header is not in srcdir.
# Same shape as a real amalgamation: URL/hash in variables, TITLE with
# spaces, EXPECTED_HASH=ALGO=hex. If NAME= is eaten, configure FATALs.

set(_pack_src "${CMAKE_CURRENT_BINARY_DIR}/pack_src")
set(_archive "${CMAKE_CURRENT_BINARY_DIR}/payload.tar.gz")

file(MAKE_DIRECTORY "${_pack_src}")
file(WRITE "${_pack_src}/payload_mark.h"
	"#ifndef PAYLOAD_MARK_H\n#define PAYLOAD_MARK_H\n#define PAYLOAD_MARK 9\n#endif\n")

execute_process(
	COMMAND ${CMAKE_COMMAND} -E tar czf "${_archive}" "payload_mark.h"
	WORKING_DIRECTORY "${_pack_src}"
	RESULT_VARIABLE _tar_rc
)
if(NOT _tar_rc EQUAL 0)
	_bm_log_message(CORE FATAL "file-to-component: tar failed")
endif()

file(SHA256 "${_archive}" _payload_hash)
file(TO_CMAKE_PATH "${_archive}" _archive_cmake)

set(PAYLOAD_URL "file://${_archive_cmake}")
set(PAYLOAD_HASH "SHA256=${_payload_hash}")

buildmaster_component(
	payload-lib
	"Harness file-to-component library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	""
	static
	"payloadlib"
	"FILES={URL=${PAYLOAD_URL};NAME=payload;UNPACK;TITLE=Harness payload data;EXPECTED_HASH=${PAYLOAD_HASH}}"
)
