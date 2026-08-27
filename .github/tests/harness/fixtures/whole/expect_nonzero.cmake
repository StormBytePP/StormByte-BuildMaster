include("${CMAKE_CURRENT_LIST_DIR}/../../../../../log.cmake")
if(COMMAND buildmaster_loglevel_init)
	buildmaster_loglevel_init()
endif()

if(NOT DEFINED EXE OR EXE STREQUAL "")
	buildmaster_message(CORE FATAL "expect_nonzero: EXE is required")
endif()

execute_process(
	COMMAND "${EXE}"
	RESULT_VARIABLE _rc
)
if(_rc EQUAL 0)
	buildmaster_message(CORE FATAL
		"expect_nonzero: ${EXE} exited 0 (expected non-zero)")
endif()
buildmaster_message(CORE INFO "expect_nonzero: ${EXE} exited ${_rc} (OK)")
