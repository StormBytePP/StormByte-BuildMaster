# =============================================================================
# env/command.cmake — command token helpers for execute_process / generated scripts
# =============================================================================

## @brief Prepare a tokenized command suitable for `execute_process(COMMAND ...)`.
## @param[out] _out Name of the variable to set in the parent scope. The
##            value is a CMake list where each element is a single token
##            suitable for expanding directly in
##            `execute_process(COMMAND ${_out} ...)`.
## @param[in] _command_list A CMake list (or the contents of a list variable)
##            representing the command and its arguments. Examples:
##            `/bin/sh;${SCRIPT}` or
##            `powershell.exe;-NoLogo;...;-File;${SCRIPT};--`.
## @note Joins list elements with spaces then calls `separate_arguments`
##       with `WINDOWS_COMMAND` or `UNIX_COMMAND` depending on the platform.
## @note Paths that already contain spaces must **not** be passed through
##       this function a second time (use the list as-is).
## @note Wrong arity is fatal (`buildmaster_message(CORE FATAL …)`).
function(prepare_command _out _command_list)
	if(NOT ARGC EQUAL 2)
		buildmaster_message(CORE FATAL
			"prepare_command requires out variable and command list"
		)
	endif()

	string(REPLACE ";" " " _command_list_spaces "${_command_list}")
	if(WIN32)
		separate_arguments(_separated_command_list WINDOWS_COMMAND "${_command_list_spaces}")
	else()
		separate_arguments(_separated_command_list UNIX_COMMAND "${_command_list_spaces}")
	endif()
	set(${_out} ${_separated_command_list} PARENT_SCOPE)
endfunction()

## @brief Format a command token list for embedding in a generated `.cmake` script.
## @param[out] out_var Parent-scope variable receiving a single string such as
##            `"powershell.exe" "-File" "C:/path/runner.ps1" "--" "C:/Program Files/.../cmake.exe"`.
## @param[in] ARGN Command tokens (already split; paths may contain spaces).
## @note Always normalizes backslashes to forward slashes so the generated
##       script does not hit invalid CMake escapes (`\S`, `\P`, …). Each
##       token is double-quoted so `set(x ...)` and `execute_process(COMMAND ...)`
##       keep paths with spaces as a single argument.
function(buildmaster_quote_cmd_list_for_script out_var)
	set(_acc "")
	foreach(_tok IN LISTS ARGN)
		string(REPLACE "\\" "/" _tok "${_tok}")
		string(REPLACE "\"" "\\\"" _tok "${_tok}")
		if(_acc STREQUAL "")
			set(_acc "\"${_tok}\"")
		else()
			set(_acc "${_acc} \"${_tok}\"")
		endif()
	endforeach()
	set(${out_var} "${_acc}" PARENT_SCOPE)
endfunction()
