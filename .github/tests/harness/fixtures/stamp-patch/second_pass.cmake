if(NOT DEFINED CMAKE_CMD OR NOT DEFINED ROOT OR NOT DEFINED TARGET
		OR NOT DEFINED REPO OR NOT DEFINED BUILDDIR)
	message(FATAL_ERROR "stamp-patch: second pass is missing arguments")
endif()
file(REMOVE "${BUILDDIR}/bm-stamp.hit")
execute_process(
	COMMAND "${CMAKE_CMD}" --build "${ROOT}" --target "${TARGET}"
	OUTPUT_VARIABLE _out
	ERROR_VARIABLE _err
	RESULT_VARIABLE _rc
)
if(NOT _rc EQUAL 0)
	message(FATAL_ERROR
		"stamp-patch: second install failed (${_rc})\n${_out}\n${_err}")
endif()
if(NOT EXISTS "${BUILDDIR}/bm-stamp.hit")
	message(FATAL_ERROR
		"stamp-patch: second install rebuilt instead of taking the stamp\n${_out}\n${_err}")
endif()
file(READ "${REPO}/CMakeLists.txt" _txt)
if(NOT _txt MATCHES "VERSION 99\\.0")
	message(FATAL_ERROR "stamp-patch: worktree was not reset\n${_txt}")
endif()
message(STATUS "stamp-patch: second install hit and worktree is upstream")
