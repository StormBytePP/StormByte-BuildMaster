## @brief Update the bootstrap env runner script based on current global
##        properties.
## @note Generates a platform-specific runner script: a Windows batch
##       file on WIN32 or a shell script on other platforms. Ensures the
##       generated Linux runner has execute permissions.
##       Propagates CMAKE_C/CXX_COMPILER_LAUNCHER and CCACHE_DIR/SCCACHE_DIR
##       only when they are non-empty so child meson/cmake builds share
##       the same compiler cache as the parent job.
##       Also propagates AR/RANLIB/NM for clang-cl LTO static archives.
function(update_env_runner)
	# Ensure template symbols exist even if the parent never set them
	if(NOT DEFINED CMAKE_C_COMPILER_LAUNCHER)
		set(CMAKE_C_COMPILER_LAUNCHER "")
	endif()
	if(NOT DEFINED CMAKE_CXX_COMPILER_LAUNCHER)
		set(CMAKE_CXX_COMPILER_LAUNCHER "")
	endif()
	if(NOT DEFINED CCACHE_DIR)
		set(CCACHE_DIR "")
	endif()
	if(NOT DEFINED SCCACHE_DIR)
		set(SCCACHE_DIR "")
	endif()
	if(NOT DEFINED BUILDMASTER_FAIL_MARKER)
		set(BUILDMASTER_FAIL_MARKER "")
	endif()

	# AR/RANLIB/NM: prefer CMake vars from CI, else ENV
	if(NOT DEFINED AR OR AR STREQUAL "")
		if(DEFINED CMAKE_AR AND NOT CMAKE_AR STREQUAL "")
			set(AR "${CMAKE_AR}")
		elseif(DEFINED ENV{AR} AND NOT "$ENV{AR}" STREQUAL "")
			set(AR "$ENV{AR}")
		else()
			set(AR "")
		endif()
	endif()
	if(NOT DEFINED RANLIB OR RANLIB STREQUAL "")
		if(DEFINED CMAKE_RANLIB AND NOT CMAKE_RANLIB STREQUAL "")
			set(RANLIB "${CMAKE_RANLIB}")
		elseif(DEFINED ENV{RANLIB} AND NOT "$ENV{RANLIB}" STREQUAL "")
			set(RANLIB "$ENV{RANLIB}")
		else()
			set(RANLIB "")
		endif()
	endif()
	if(NOT DEFINED NM OR NM STREQUAL "")
		if(DEFINED CMAKE_NM AND NOT CMAKE_NM STREQUAL "")
			set(NM "${CMAKE_NM}")
		elseif(DEFINED ENV{NM} AND NOT "$ENV{NM}" STREQUAL "")
			set(NM "$ENV{NM}")
		else()
			set(NM "")
		endif()
	endif()

	# Paths safe for CMake templates / runners
	if(NOT AR STREQUAL "")
		normalize_cmake_path(AR "${AR}")
	endif()
	if(NOT RANLIB STREQUAL "")
		normalize_cmake_path(RANLIB "${RANLIB}")
	endif()
	if(NOT NM STREQUAL "")
		normalize_cmake_path(NM "${NM}")
	endif()

	if(WIN32)
		configure_file(
			"${BUILDMASTER_SRCDIR}/env/runner_windows.bat.in"
			"${BUILDMASTER_SCRIPTS_ENVDIR}/runner.bat"
			@ONLY
		)
	else()
		configure_file(
			"${BUILDMASTER_SRCDIR}/env/runner_linux.sh.in"
			"${BUILDMASTER_SCRIPTS_ENVDIR}/runner.sh"
			@ONLY
		)

		execute_process(
			COMMAND ${CMAKE_COMMAND} -E chmod 0755 "${BUILDMASTER_SCRIPTS_ENVDIR}/runner.sh"
			RESULT_VARIABLE _chmod_result
			OUTPUT_QUIET
			ERROR_QUIET
		)
	endif()
endfunction()

## @brief Prepare a tokenized command suitable for `execute_process(COMMAND ...)`.
## @param[out] _out Name of the variable to set in the parent scope. The
##            value will be a CMake list where each element is a single
##            token (argument) suitable for expanding directly in
##            `execute_process(COMMAND ${_out} ...)`.
## @param[in] _command_list A CMake list (or the name of a variable
##            containing a list) representing the command and its
##            arguments. Examples: `/bin/sh;${SCRIPT}` or
##            `cmd;/C;${SCRIPT}`.
## @note Joins list elements with spaces then calls `separate_arguments`
##       with `WINDOWS_COMMAND` or `UNIX_COMMAND` depending on the
##       platform. The returned `_out` is a proper CMake list of tokens
##       so callers must expand it as multiple arguments in
##       `execute_process`, not as a single quoted string. The function
##       requires exactly two arguments and will `FATAL_ERROR` if called
##       incorrectly.
##
## Example:
##   set(_cmd /bin/sh "${BUILDMASTER_SCRIPTS_ENVDIR}/runner.sh")
##   prepare_command(ENV_RUNNER "${_cmd}")
##   execute_process(COMMAND ${ENV_RUNNER} --version WORKING_DIRECTORY ${WD})
##
## This produces a token list such as `/bin/sh` and
## `/path/to/runner.sh` so `execute_process` receives them as separate
## arguments.
function(prepare_command _out _command_list)
	if(NOT ARGC EQUAL 2)
		message(FATAL_ERROR "prepare_command requires out variable and command list")
	endif()

	string(REPLACE ";" " " _command_list_spaces "${_command_list}")
	if(WIN32)
		separate_arguments(_separated_command_list WINDOWS_COMMAND "${_command_list_spaces}")
	else()
		separate_arguments(_separated_command_list UNIX_COMMAND "${_command_list_spaces}")
	endif()
	# Return the tokenized command as a proper CMake list so callers can
	# pass it directly to `execute_process(COMMAND ...)` as multiple args.
	set(${_out} ${_separated_command_list} PARENT_SCOPE)
endfunction()
