## @brief Update the bootstrap env runner script based on current global
##        properties.
## @note Generates a platform-specific runner: PowerShell on WIN32
##       (`-ExecutionPolicy Bypass -File`, process-local only) or a shell
##       script elsewhere. Ensures the generated Linux runner is executable.
##       Propagates CMAKE_C/CXX_COMPILER_LAUNCHER and CCACHE_DIR/SCCACHE_DIR
##       only when they are non-empty so child meson/cmake builds share
##       the same compiler cache as the parent job.
##       Also propagates AR/RANLIB/NM for clang-cl LTO static archives.
function(update_env_runner)
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
			"${BUILDMASTER_SRCDIR}/env/runner_windows.ps1.in"
			"${BUILDMASTER_SCRIPTS_ENVDIR}/runner.ps1"
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
##            `powershell.exe;-NoLogo;...;-File;${SCRIPT};--`.
## @note Joins list elements with spaces then calls `separate_arguments`
##       with `WINDOWS_COMMAND` or `UNIX_COMMAND` depending on the
##       platform. Paths that already contain spaces must NOT be passed
##       through this function a second time (use the list as-is).
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

## @brief Generate component-local env runners from a loaded toolchain profile.
## @param[out] out_runner Caller-scope variable receiving the tokenized
##            normal runner command (same shape as ENV_RUNNER).
## @param[out] out_runner_silent Caller-scope variable receiving the tokenized
##            silent runner command (same shape as ENV_RUNNER_SILENT).
## @param[in] component Component id used to name the generated scripts.
## @param[in] toolchain_name Normalized toolchain name (e.g. msvc, clang-cl).
## @note Implemented as a macro so BM_TC_* and PATH from the caller
##       (create_*_stages after buildmaster_load_toolchain_profile) are visible.
##       Requires BM_TC_* already set in the caller. Writes runner_<safe> and
##       runner_silent_<safe> under BUILDMASTER_SCRIPTS_ENVDIR. The silent
##       script invokes the matching component normal runner (not the global
##       parent runner). On WIN32 the silent template receives ENV_RUNNER_CMD
##       as the absolute path of that .ps1; CMake launches both via
##       powershell -ExecutionPolicy Bypass -File (process-local).
macro(buildmaster_create_component_env_runners out_runner out_runner_silent component toolchain_name)
	if("${component}" STREQUAL "" OR "${toolchain_name}" STREQUAL "")
		message(FATAL_ERROR
			"[BuildMaster] buildmaster_create_component_env_runners: "
			"component and toolchain_name must be non-empty"
		)
	endif()

	sanitize_for_filename(_bm_tc_safe "${component}_${toolchain_name}")

	set(CMAKE_C_COMPILER "${BM_TC_C_COMPILER}")
	set(CMAKE_CXX_COMPILER "${BM_TC_CXX_COMPILER}")
	set(AR "${BM_TC_AR}")
	set(RANLIB "${BM_TC_RANLIB}")
	set(NM "${BM_TC_NM}")

	if(NOT AR STREQUAL "")
		normalize_cmake_path(AR "${AR}")
	endif()
	if(NOT RANLIB STREQUAL "")
		normalize_cmake_path(RANLIB "${RANLIB}")
	endif()
	if(NOT NM STREQUAL "")
		normalize_cmake_path(NM "${NM}")
	endif()

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
	if(NOT DEFINED PKG_CONFIG)
		set(PKG_CONFIG "")
	endif()
	if(NOT DEFINED PKG_CONFIG_PATH)
		set(PKG_CONFIG_PATH "")
	endif()
	if(NOT DEFINED PATH)
		set(PATH "")
	endif()
	if(NOT DEFINED NPROC)
		set(NPROC "")
	endif()
	if(NOT DEFINED CFLAGS)
		set(CFLAGS "")
	endif()
	if(NOT DEFINED CXXFLAGS)
		set(CXXFLAGS "")
	endif()
	if(NOT DEFINED LDFLAGS)
		set(LDFLAGS "")
	endif()
	if(NOT DEFINED LIB)
		set(LIB "")
	endif()
	if(NOT DEFINED INCLUDE)
		set(INCLUDE "")
	endif()

	if(WIN32)
		set(_bm_tc_runner_path "${BUILDMASTER_SCRIPTS_ENVDIR}/runner_${_bm_tc_safe}.ps1")
		set(_bm_tc_silent_path "${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent_${_bm_tc_safe}.ps1")
		normalize_cmake_path(_bm_tc_runner_path_cmake "${_bm_tc_runner_path}")
		normalize_cmake_path(_bm_tc_silent_path_cmake "${_bm_tc_silent_path}")

		configure_file(
			"${BUILDMASTER_SRCDIR}/env/runner_windows.ps1.in"
			"${_bm_tc_runner_path}"
			@ONLY
		)
		# Path only — silent .ps1 does powershell -File $runner
		set(ENV_RUNNER_CMD "${_bm_tc_runner_path_cmake}")
		configure_file(
			"${BUILDMASTER_SRCDIR}/env/runner_windows_silent.ps1.in"
			"${_bm_tc_silent_path}"
			@ONLY
		)
		set(_bm_pwsh powershell.exe -NoLogo -NoProfile -NonInteractive
			-ExecutionPolicy Bypass -File)
		set(_bm_tc_runner_cmd ${_bm_pwsh} "${_bm_tc_runner_path_cmake}" --)
		set(_bm_tc_silent_cmd ${_bm_pwsh} "${_bm_tc_silent_path_cmake}" --)
	else()
		set(_bm_tc_runner_path "${BUILDMASTER_SCRIPTS_ENVDIR}/runner_${_bm_tc_safe}.sh")
		set(_bm_tc_silent_path "${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent_${_bm_tc_safe}.sh")
		configure_file(
			"${BUILDMASTER_SRCDIR}/env/runner_linux.sh.in"
			"${_bm_tc_runner_path}"
			@ONLY
		)
		execute_process(
			COMMAND ${CMAKE_COMMAND} -E chmod 0755 "${_bm_tc_runner_path}"
			OUTPUT_QUIET
			ERROR_QUIET
		)
		set(ENV_RUNNER_CMD "/bin/sh \"${_bm_tc_runner_path}\"")
		configure_file(
			"${BUILDMASTER_SRCDIR}/env/runner_linux_silent.sh.in"
			"${_bm_tc_silent_path}"
			@ONLY
		)
		execute_process(
			COMMAND ${CMAKE_COMMAND} -E chmod 0755 "${_bm_tc_silent_path}"
			OUTPUT_QUIET
			ERROR_QUIET
		)
		set(_bm_tc_runner_cmd /bin/sh "${_bm_tc_runner_path}")
		set(_bm_tc_silent_cmd /bin/sh "${_bm_tc_silent_path}")
	endif()

	set(${out_runner} ${_bm_tc_runner_cmd})
	set(${out_runner_silent} ${_bm_tc_silent_cmd})
endmacro()
