## @brief Update the bootstrap env runner script based on current global
##        properties.
## @note Generates a platform-specific runner script: a Windows batch
##       file on WIN32 or a shell script on other platforms. Ensures the
##       generated Linux runner has execute permissions.
function(update_env_runner)
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

		# Ensure the generated runner has execute permissions so it can be
		# invoked directly by execute_process(). Some platforms require the
		# executable bit even when a shebang is present.
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