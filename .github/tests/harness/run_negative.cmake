if(NOT BM_TEST_REPO_ROOT OR NOT BM_TEST_NEGATIVE_DIR)
	message(FATAL_ERROR "run_negative: BM_TEST_REPO_ROOT / BM_TEST_NEGATIVE_DIR unset")
endif()

set(_gen_args)
if(CMAKE_GENERATOR)
	list(APPEND _gen_args -G "${CMAKE_GENERATOR}")
endif()

set(_cfg_cases missing-hook bad-linkflags files-on-meta group-cycle group-link)
set(_ins_cases pc-clobber)
set(_failed 0)

foreach(_c IN LISTS _cfg_cases)
	set(_s "${BM_TEST_NEGATIVE_DIR}/${_c}")
	set(_b "${CMAKE_CURRENT_BINARY_DIR}/negative_${_c}")
	file(REMOVE_RECURSE "${_b}")
	execute_process(
		COMMAND ${CMAKE_COMMAND}
			-S "${_s}"
			-B "${_b}"
			${_gen_args}
			-DBM_TEST_REPO_ROOT=${BM_TEST_REPO_ROOT}
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	if(_rc EQUAL 0)
		message(STATUS "negative/${_c} CONFIGURED (expected FATAL)")
		math(EXPR _failed "${_failed} + 1")
	else()
		message(STATUS "[BuildMaster/Core     ]: negative/${_c} configure-failed as required")
	endif()
endforeach()

foreach(_c IN LISTS _ins_cases)
	set(_s "${BM_TEST_NEGATIVE_DIR}/${_c}")
	set(_b "${CMAKE_CURRENT_BINARY_DIR}/negative_${_c}")
	file(REMOVE_RECURSE "${_b}")
	execute_process(
		COMMAND ${CMAKE_COMMAND}
			-S "${_s}"
			-B "${_b}"
			${_gen_args}
			-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
			-DBM_TEST_REPO_ROOT=${BM_TEST_REPO_ROOT}
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		message(STATUS "negative/${_c} configure died (wanted install FATAL)\n${_err}")
		math(EXPR _failed "${_failed} + 1")
		continue()
	endif()
	execute_process(
		COMMAND ${CMAKE_COMMAND} --build "${_b}" --target pc-clash_install
		RESULT_VARIABLE _brc
		OUTPUT_VARIABLE _bout
		ERROR_VARIABLE _berr
	)
	if(_brc EQUAL 0)
		message(STATUS "negative/${_c} INSTALL succeeded (expected FATAL)")
		math(EXPR _failed "${_failed} + 1")
	else()
		string(JOIN "\n" _blob "${_bout}" "${_berr}")
		string(FIND "${_blob}" "already exists (upstream .pc)" _hit)
		if(_hit LESS 0)
			message(STATUS "negative/${_c} install failed but not with pc-clobber text:\n${_blob}")
			math(EXPR _failed "${_failed} + 1")
		else()
			message(STATUS "[BuildMaster/Core     ]: negative/${_c} install-failed as required")
		endif()
	endif()
endforeach()

if(_failed GREATER 0)
	message(FATAL_ERROR "negative: ${_failed} case(s) did not match the contract")
endif()
