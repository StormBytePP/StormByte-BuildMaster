# =============================================================================
# env/runner.cmake — platform env runners (parent + per-component)
# =============================================================================

## @brief Update the bootstrap env runner script from current CMake / ENV state.
## @note Generates a platform-specific runner: PowerShell on WIN32
##       (`runner.ps1`, launched with `-ExecutionPolicy Bypass -File`,
##       process-local only) or a POSIX shell script elsewhere (`runner.sh`).
##       Ensures the generated Linux runner is executable (`chmod 0755`).
## @note Propagates `CMAKE_C_COMPILER_LAUNCHER`, `CMAKE_CXX_COMPILER_LAUNCHER`,
##       `CCACHE_DIR` and `SCCACHE_DIR` only when they are defined so child
##       Meson/CMake builds share the same compiler cache as the parent job.
## @note Resolves `AR` / `RANLIB` / `NM` from `CMAKE_AR` / `CMAKE_RANLIB` /
##       `CMAKE_NM` or `ENV{AR,RANLIB,NM}` when the variables are unset, then
##       normalizes them with `normalize_cmake_path` so Windows paths are safe
##       inside the generated runner and toolchain dump.
## @note Does not rewrite per-component runners; those are produced by
##       `buildmaster_create_component_env_runners` after a profile load.
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

## @brief Generate component-local env runners from a loaded toolchain profile.
## @param[out] out_runner Caller-scope variable receiving the tokenized
##            normal runner command (same shape as `ENV_RUNNER`).
## @param[out] out_runner_silent Caller-scope variable receiving the tokenized
##            silent runner command (same shape as `ENV_RUNNER_SILENT`).
## @param[in] component Component id used to name the generated scripts.
## @param[in] toolchain_name Normalized toolchain name (e.g. `msvc`, `clang-cl`).
## @note Implemented as a **macro** so `BM_TC_*` and `PATH` from the caller
##       (`create_*_stages` after `buildmaster_load_toolchain_profile`) are
##       visible without extra PARENT_SCOPE plumbing.
## @note Requires `BM_TC_*` already set in the caller. Writes
##       `runner_<safe>` and `runner_silent_<safe>` under
##       `BUILDMASTER_SCRIPTS_ENVDIR`. The silent script invokes the matching
##       component **normal** runner (not the global parent runner).
## @note On WIN32 the silent template receives `ENV_RUNNER_CMD` as the
##       absolute path of that `.ps1`; CMake launches both via
##       `powershell -ExecutionPolicy Bypass -File` (process-local).
## @note Empty `component` or `toolchain_name` is fatal.
macro(buildmaster_create_component_env_runners out_runner out_runner_silent component toolchain_name)
	if("${component}" STREQUAL "" OR "${toolchain_name}" STREQUAL "")
		buildmaster_message(TOOLCHAIN FATAL
			"buildmaster_create_component_env_runners: component and toolchain_name must be non-empty"
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
