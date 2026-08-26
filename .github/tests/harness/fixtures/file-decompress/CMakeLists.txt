# Build a tiny archive under the binary dir, then file_decompress into extract/.

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

file_decompress(bm_file_decompress
	"${_archive}"
	"${_extract}"
	TITLE "Harness sample archive"
	COMMENT "Decompress harness sample.tar.gz"
)

add_custom_target(file_decompress_check
	DEPENDS bm_file_decompress
	COMMAND ${CMAKE_COMMAND}
		-DFILE=${_extract}/hello.txt
		-DEXPECT=buildmaster-file-decompress
		-P "${CMAKE_CURRENT_SOURCE_DIR}/check_hello.cmake"
	COMMENT "Verify file_decompress output"
	VERBATIM
)

file(SHA256 "${_archive}" _archive_sha)
file_checksum_correct(_ck_ok "${_archive}" "SHA256=${_archive_sha}")
if(NOT _ck_ok)
	message(FATAL_ERROR
		"file-decompress fixture: file_checksum_correct failed on sample archive")
endif()
file_checksum_correct(_ck_bad "${_archive}"
	"SHA256=0000000000000000000000000000000000000000000000000000000000000000")
if(_ck_bad)
	message(FATAL_ERROR
		"file-decompress fixture: file_checksum_correct should reject wrong hash")
endif()
