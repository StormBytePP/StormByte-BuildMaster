include("${CMAKE_CURRENT_LIST_DIR}/../../../../../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

if(NOT DEFINED EXE OR EXE STREQUAL "")
	_bm_log_message(CORE FATAL "expect_nonzero: EXE is required")
endif()

execute_process(
	COMMAND "${EXE}"
	RESULT_VARIABLE _rc
)
if(_rc EQUAL 0)
	_bm_log_message(CORE FATAL
		"expect_nonzero: ${EXE} exited 0 (expected non-zero)")
endif()
_bm_log_message(CORE INFO "expect_nonzero: ${EXE} exited ${_rc} (OK)")
