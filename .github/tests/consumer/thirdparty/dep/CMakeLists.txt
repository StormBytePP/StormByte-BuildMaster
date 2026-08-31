set(CONSUMERDEP_SRCDIR "${CMAKE_CURRENT_SOURCE_DIR}/lib")
set(CONSUMERDEP_PATCH "${CMAKE_CURRENT_SOURCE_DIR}/0001-fix-typo.patch")

# Seed a git worktree so GIT={RESET;PATCH} has something to apply.
# Not part of the public BM API; the consumer still has to have git on PATH.
_bm_tools_demand_named(git)

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

buildmaster_component(
	consumer-dep
	"Consumer-style dependant library"
	"${CONSUMERDEP_SRCDIR}"
	""
	"static"
	"consumerdep"
	"INDENT=1;GIT={RESET;PATCH=${CONSUMERDEP_PATCH};TITLE=fix typo}"
)
