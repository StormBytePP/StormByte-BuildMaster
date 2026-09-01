if(NOT BM_TEST_REPO_ROOT OR NOT BM_TEST_NEGATIVE_DIR)
	message(FATAL_ERROR "run_negative: BM_TEST_REPO_ROOT / BM_TEST_NEGATIVE_DIR unset")
endif()

set(_gen_args)
if(CMAKE_GENERATOR)
	list(APPEND _gen_args -G "${CMAKE_GENERATOR}")
endif()

set(_cfg_cases
	missing-hook
	bad-linkflags
	files-on-meta
	hash-mismatch
	buildonly-removed
	noinstall-off
	backend-ambiguous
	backend-pick-cmake
	repack-plus-noinstall
	repack-headers
	repack-two-produced
	repack-on-component-empty
)
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
		if(_c STREQUAL "hash-mismatch")
			string(JOIN "\n" _blob "${_out}" "${_err}")
			string(FIND "${_blob}" "Hash mismatch" _hit)
			if(_hit LESS 0)
				message(STATUS "negative/${_c} configure failed but not with hash-mismatch text:\n${_blob}")
				math(EXPR _failed "${_failed} + 1")
			else()
				message(STATUS "[BuildMaster/Core     ]: negative/${_c} configure-failed as required")
			endif()
		elseif(_c STREQUAL "buildonly-removed")
			string(JOIN "\n" _blob "${_out}" "${_err}")
			string(FIND "${_blob}" "BUILDONLY is removed" _hit)
			if(_hit LESS 0)
				message(STATUS "negative/${_c} configure failed but not with BUILDONLY-removed text:\n${_blob}")
				math(EXPR _failed "${_failed} + 1")
			else()
				message(STATUS "[BuildMaster/Core     ]: negative/${_c} configure-failed as required")
			endif()
		elseif(_c STREQUAL "noinstall-off")
			string(JOIN "\n" _blob "${_out}" "${_err}")
			string(FIND "${_blob}" "NOINSTALL cannot be turned off" _hit)
			if(_hit LESS 0)
				message(STATUS "negative/${_c} configure failed but not with NOINSTALL-off text:\n${_blob}")
				math(EXPR _failed "${_failed} + 1")
			else()
				message(STATUS "[BuildMaster/Core     ]: negative/${_c} configure-failed as required")
			endif()
		elseif(_c STREQUAL "repack-plus-noinstall")
			string(JOIN "\n" _blob "${_out}" "${_err}")
			string(FIND "${_blob}" "REPACK cannot be combined with NOINSTALL" _hit)
			if(_hit LESS 0)
				message(STATUS "negative/${_c} configure failed but not with REPACK+NOINSTALL text:\n${_blob}")
				math(EXPR _failed "${_failed} + 1")
			else()
				message(STATUS "[BuildMaster/Core     ]: negative/${_c} configure-failed as required")
			endif()
		elseif(_c STREQUAL "repack-headers")
			string(JOIN "\n" _blob "${_out}" "${_err}")
			string(FIND "${_blob}" "REPACK is not valid in headers mode" _hit)
			if(_hit LESS 0)
				message(STATUS "negative/${_c} configure failed but not with REPACK-headers text:\n${_blob}")
				math(EXPR _failed "${_failed} + 1")
			else()
				message(STATUS "[BuildMaster/Core     ]: negative/${_c} configure-failed as required")
			endif()
		elseif(_c STREQUAL "repack-two-produced")
			string(JOIN "\n" _blob "${_out}" "${_err}")
			string(FIND "${_blob}" "REPACK requires exactly one produced spec" _hit)
			if(_hit LESS 0)
				message(STATUS "negative/${_c} configure failed but not with two-produced text:\n${_blob}")
				math(EXPR _failed "${_failed} + 1")
			else()
				message(STATUS "[BuildMaster/Core     ]: negative/${_c} configure-failed as required")
			endif()
		elseif(_c STREQUAL "repack-on-component-empty")
			string(JOIN "\n" _blob "${_out}" "${_err}")
			string(FIND "${_blob}" "REPACK requires at least one" _hit)
			if(_hit LESS 0)
				message(STATUS "negative/${_c} configure failed but not with empty-members text:\n${_blob}")
				math(EXPR _failed "${_failed} + 1")
			else()
				message(STATUS "[BuildMaster/Core     ]: negative/${_c} configure-failed as required")
			endif()
		else()
			message(STATUS "[BuildMaster/Core     ]: negative/${_c} configure-failed as required")
		endif()
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
