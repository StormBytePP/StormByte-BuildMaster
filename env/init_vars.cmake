if(NOT BUILDMASTER_CONFIGURED)
	set(BUILDMASTER_ENV_SRCDIR "${CMAKE_CURRENT_LIST_DIR}")
	set(BUILDMASTER_SCRIPTS_ENVDIR "${BUILDMASTER_BINDIR}/scripts/env")
	if(WIN32)
		# Bypass applies only to this powershell.exe process (does not
		# change machine/user ExecutionPolicy). -File avoids -Command.
		set(_bm_pwsh powershell.exe -NoLogo -NoProfile -NonInteractive
			-ExecutionPolicy Bypass -File)
		set(ENV_RUNNER
			${_bm_pwsh}
			"${BUILDMASTER_SCRIPTS_ENVDIR}/runner.ps1"
			--)
		set(ENV_RUNNER_SILENT
			${_bm_pwsh}
			"${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.ps1"
			--)
		# Path only: the silent .ps1 launches this file with -File.
		set(ENV_RUNNER_CMD "${BUILDMASTER_SCRIPTS_ENVDIR}/runner.ps1")
		set(ENV_RUNNER_SILENT_CMD "${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.ps1")
		configure_file(
			"${BUILDMASTER_ENV_SRCDIR}/runner_windows_silent.ps1.in"
			"${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.ps1"
			@ONLY
		)
	else()
		set(ENV_RUNNER /bin/sh "${BUILDMASTER_SCRIPTS_ENVDIR}/runner.sh")
		set(ENV_RUNNER_SILENT bash "${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.sh")
		set(ENV_RUNNER_CMD "/bin/sh ${BUILDMASTER_SCRIPTS_ENVDIR}/runner.sh")
		set(ENV_RUNNER_SILENT_CMD "bash ${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.sh")
		configure_file(
			"${BUILDMASTER_ENV_SRCDIR}/runner_linux_silent.sh.in"
			"${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.sh"
			@ONLY
		)
		execute_process(
			COMMAND ${CMAKE_COMMAND} -E chmod 0755 "${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.sh"
			RESULT_VARIABLE _chmod_result
			OUTPUT_QUIET
			ERROR_QUIET
		)
	endif()

	include(ProcessorCount)
	ProcessorCount(NPROC)
	if(NOT NPROC OR NPROC STREQUAL "0")
		set(NPROC 1)
	endif()
	set(NPROC "${NPROC}" CACHE INTERNAL "BuildMaster persisted job count")

	# Compiler launchers: CMake does not load these from the environment by itself.
	# Prefer already-set CMake vars (-D from CI); else take ENV from the job.
	if(NOT CMAKE_C_COMPILER_LAUNCHER AND DEFINED ENV{CMAKE_C_COMPILER_LAUNCHER}
			AND NOT "$ENV{CMAKE_C_COMPILER_LAUNCHER}" STREQUAL "")
		set(CMAKE_C_COMPILER_LAUNCHER "$ENV{CMAKE_C_COMPILER_LAUNCHER}")
	endif()
	if(NOT CMAKE_CXX_COMPILER_LAUNCHER AND DEFINED ENV{CMAKE_CXX_COMPILER_LAUNCHER}
			AND NOT "$ENV{CMAKE_CXX_COMPILER_LAUNCHER}" STREQUAL "")
		set(CMAKE_CXX_COMPILER_LAUNCHER "$ENV{CMAKE_CXX_COMPILER_LAUNCHER}")
	endif()
	if(NOT DEFINED CMAKE_C_COMPILER_LAUNCHER)
		set(CMAKE_C_COMPILER_LAUNCHER "")
	endif()
	if(NOT DEFINED CMAKE_CXX_COMPILER_LAUNCHER)
		set(CMAKE_CXX_COMPILER_LAUNCHER "")
	endif()

	# Cache dirs: only when the job actually enabled caching
	if(DEFINED ENV{CCACHE_DIR} AND NOT "$ENV{CCACHE_DIR}" STREQUAL "")
		set(CCACHE_DIR "$ENV{CCACHE_DIR}")
	else()
		set(CCACHE_DIR "")
	endif()
	if(DEFINED ENV{SCCACHE_DIR} AND NOT "$ENV{SCCACHE_DIR}" STREQUAL "")
		set(SCCACHE_DIR "$ENV{SCCACHE_DIR}")
	else()
		set(SCCACHE_DIR "")
	endif()

	# AR / RANLIB / NM from parent CI (clang-cl LTO) or environment
	if(DEFINED CMAKE_AR AND NOT CMAKE_AR STREQUAL "")
		set(AR "${CMAKE_AR}")
	elseif(DEFINED ENV{AR} AND NOT "$ENV{AR}" STREQUAL "")
		set(AR "$ENV{AR}")
	else()
		set(AR "")
	endif()
	if(DEFINED CMAKE_RANLIB AND NOT CMAKE_RANLIB STREQUAL "")
		set(RANLIB "${CMAKE_RANLIB}")
	elseif(DEFINED ENV{RANLIB} AND NOT "$ENV{RANLIB}" STREQUAL "")
		set(RANLIB "$ENV{RANLIB}")
	else()
		set(RANLIB "")
	endif()
	if(DEFINED CMAKE_NM AND NOT CMAKE_NM STREQUAL "")
		set(NM "${CMAKE_NM}")
	elseif(DEFINED ENV{NM} AND NOT "$ENV{NM}" STREQUAL "")
		set(NM "$ENV{NM}")
	else()
		set(NM "")
	endif()

	if(NOT DEFINED INCLUDE)
		set(INCLUDE "")
	endif()
	if(NOT DEFINED LIB)
		set(LIB "")
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

	# Fill the 1.0.0 runner placeholders from the shared prefix.
	# CMAKE_*_FLAGS here live in this directory; create_*_stages must
	# call the same helper so nested configure.cmake.in is not empty.
	include("${CMAKE_CURRENT_LIST_DIR}/prefix_search.cmake")
	if(COMMAND _bm_env_apply_install_search_paths)
		_bm_env_apply_install_search_paths()
	endif()

	_bm_env_prepare_command(ENV_RUNNER "${ENV_RUNNER}")

	# Compile-only runner: silent by default; full output when BUILDMASTER_VERBOSE
	if(BUILDMASTER_VERBOSE)
		set(ENV_RUNNER_COMPILE ${ENV_RUNNER})
	else()
		set(ENV_RUNNER_COMPILE ${ENV_RUNNER_SILENT})
	endif()

	_bm_env_update_runner()

	include("${CMAKE_CURRENT_LIST_DIR}/update_toolchain.cmake")
endif()
