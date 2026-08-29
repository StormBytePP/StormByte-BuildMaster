# Build a tiny archive under the binary dir, then buildmaster_decompress into extract/.

set(_pack_src "${CMAKE_CURRENT_BINARY_DIR}/pack_src")
set(_archive "${CMAKE_CURRENT_BINARY_DIR}/sample.tar.gz")
set(_extract "${CMAKE_CURRENT_BINARY_DIR}/extract")

file(MAKE_DIRECTORY "${_pack_src}")
file(WRITE "${_pack_src}/hello.txt" "buildmaster-file-decompress\n")

execute_process(
	COMMAND ${CMAKE_COMMAND} -E tar czf "${_archive}" "hello.txt"
	WORKING_DIRECTORY "${_pack_src}"
	RESULT_VARIABLE _tar_rc
)
if(NOT _tar_rc EQUAL 0)
	message(FATAL_ERROR "file-decompress fixture: failed to create sample.tar.gz")
endif()

buildmaster_decompress(bm_buildmaster_decompress
	"${_archive}"
	"${_extract}"
	TITLE "Harness sample archive"
	COMMENT "Decompress harness sample.tar.gz"
)

add_custom_target(buildmaster_decompress_check
	DEPENDS bm_buildmaster_decompress
	COMMAND ${CMAKE_COMMAND}
		-DFILE=${_extract}/hello.txt
		-DEXPECT=buildmaster-file-decompress
		-P "${CMAKE_CURRENT_SOURCE_DIR}/check_hello.cmake"
	COMMENT "Verify buildmaster_decompress output"
	VERBATIM
)

file(SHA256 "${_archive}" _archive_sha)
_bm_tools_file_checksum(_ck_ok "${_archive}" "SHA256=${_archive_sha}")
if(NOT _ck_ok)
	message(FATAL_ERROR
		"file-decompress fixture: _bm_tools_file_checksum failed on sample archive")
endif()
_bm_tools_file_checksum(_ck_bad "${_archive}"
	"SHA256=0000000000000000000000000000000000000000000000000000000000000000")
if(_ck_bad)
	message(FATAL_ERROR
		"file-decompress fixture: _bm_tools_file_checksum should reject wrong hash")
endif()
