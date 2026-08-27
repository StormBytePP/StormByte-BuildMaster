# cmake -DEXE=... -P expect_nonzero.cmake
if(NOT EXE)
	message(FATAL_ERROR "expect_nonzero: need -DEXE=")
endif()
execute_process(COMMAND "${EXE}" RESULT_VARIABLE _r)
if(_r EQUAL 0)
	message(FATAL_ERROR "expect_nonzero: ${EXE} exited 0 (expected non-zero without WHOLE)")
endif()
message(STATUS "expect_nonzero: ${EXE} exited ${_r} (OK)")
