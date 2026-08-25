if(NOT BUILDMASTER_CONFIGURED)
	set(BUILDMASTER_ENV_SRCDIR "${CMAKE_CURRENT_LIST_DIR}")
	set(BUILDMASTER_SCRIPTS_ENVDIR "${BUILDMASTER_BINDIR}/scripts/env")
	if(WIN32)
		set(ENV_RUNNER cmd "/C" "${BUILDMASTER_SCRIPTS_ENVDIR}/runner.bat")
		set(ENV_RUNNER_SILENT cmd "/C" "${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.bat")
		set(ENV_RUNNER_CMD "cmd /C ${BUILDMASTER_SCRIPTS_ENVDIR}/runner.bat")
		set(ENV_RUNNER_SILENT_CMD "cmd /C ${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.bat")
		configure_file(
			"${BUILDMASTER_ENV_SRCDIR}/runner_windows_silent.bat.in"
			"${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.bat"
			@ONLY
		)
	else()
		set(ENV_RUNNER /bin/sh "${BUILDMASTER_SCRIPTS_ENVDIR}/runner.sh")
		set(ENV_RUNNER_SILENT /bin/sh "${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.sh")
		set(ENV_RUNNER_CMD "/bin/sh ${BUILDMASTER_SCRIPTS_ENVDIR}/runner.sh")
		set(ENV_RUNNER_SILENT_CMD "/bin/sh ${BUILDMASTER_SCRIPTS_ENVDIR}/runner_silent.sh")
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

	prepare_command(ENV_RUNNER "${ENV_RUNNER}")

	if(BUILDMASTER_DEBUG)
		set(ENV_RUNNER_SILENT "${ENV_RUNNER}")
	endif()

	# Compile-only runner: silent by default; full output when BUILDMASTER_VERBOSE
	# DEBUG alone does not force verbose compile flags — only this alias + *_VERBOSE_ARGS
	if(BUILDMASTER_VERBOSE)
		set(ENV_RUNNER_COMPILE ${ENV_RUNNER})
	else()
		set(ENV_RUNNER_COMPILE ${ENV_RUNNER_SILENT})
	endif()

	update_env_runner()

	include("${CMAKE_CURRENT_LIST_DIR}/update_toolchain.cmake")
endif()
