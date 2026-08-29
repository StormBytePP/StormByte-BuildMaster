if(NOT EXISTS "${FILE}")
	message(FATAL_ERROR "buildmaster_decompress check: missing ${FILE}")
endif()
file(READ "${FILE}" _content)
string(STRIP "${_content}" _content)
if(NOT _content STREQUAL "${EXPECT}")
	message(FATAL_ERROR
		"buildmaster_decompress check: content mismatch\n"
		"  expected: ${EXPECT}\n"
		"  actual:   ${_content}")
endif()
message(STATUS "buildmaster_decompress check: OK")