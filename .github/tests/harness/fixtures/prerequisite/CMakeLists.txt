# Custom prerequisite target before a tiny static component.

buildmaster_prerequisite(prereq_touch
	COMMAND ${CMAKE_COMMAND} -E touch
		"${CMAKE_CURRENT_BINARY_DIR}/prereq.stamp"
	COMMENT "Harness prerequisite touch"
)

_bm_path_builddir(PREREQ_LIB_BUILD_DIR "prereq-lib")
_bm_comp_cmake_create(
	prereq-lib
	"Harness prerequisite consumer"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${PREREQ_LIB_BUILD_DIR}"
	""
	static
	"prereqlib"
)
buildmaster_depend(prereq-lib prereq_touch)