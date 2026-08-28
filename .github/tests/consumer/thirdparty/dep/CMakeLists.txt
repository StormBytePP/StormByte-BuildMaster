ensure_build_dir(CONSUMERDEP_BUILDDIR)

set(CONSUMERDEP_SRCDIR "${CMAKE_CURRENT_SOURCE_DIR}/lib")
set(CONSUMERDEP_PATCH "${CMAKE_CURRENT_SOURCE_DIR}/0001-fix-typo.patch")

if(NOT GIT_EXECUTABLE)
	message(FATAL_ERROR "consumer-dep: GIT_EXECUTABLE is required")
endif()

if(NOT EXISTS "${CONSUMERDEP_SRCDIR}/.git")
	execute_process(
		COMMAND ${GIT_EXECUTABLE} init
		WORKING_DIRECTORY "${CONSUMERDEP_SRCDIR}"
		RESULT_VARIABLE _rc
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		message(FATAL_ERROR "consumer-dep: git init failed: ${_err}")
	endif()
	execute_process(COMMAND ${GIT_EXECUTABLE} -C "${CONSUMERDEP_SRCDIR}" config user.email "harness@buildmaster")
	execute_process(COMMAND ${GIT_EXECUTABLE} -C "${CONSUMERDEP_SRCDIR}" config user.name "BuildMaster harness")
	execute_process(COMMAND ${GIT_EXECUTABLE} -C "${CONSUMERDEP_SRCDIR}" add -A)
	execute_process(
		COMMAND ${GIT_EXECUTABLE} -C "${CONSUMERDEP_SRCDIR}" commit --no-gpg-sign -m "upstream with typo"
		RESULT_VARIABLE _rc
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		message(FATAL_ERROR "consumer-dep: git commit failed: ${_err}")
	endif()
endif()

create_git_patch_file(
	consumer-dep
	"fix typo"
	"${CONSUMERDEP_SRCDIR}"
	"${CONSUMERDEP_PATCH}"
)
create_git_reset_file(
	consumer-dep
	"dep reset"
	"${CONSUMERDEP_SRCDIR}"
)

create_cmake_component(
	consumer-dep
	"Consumer-style dependant library"
	"${CONSUMERDEP_SRCDIR}"
	"${CONSUMERDEP_BUILDDIR}"
	""
	"static"
	"consumerdep"
	"INDENT=1"
)
