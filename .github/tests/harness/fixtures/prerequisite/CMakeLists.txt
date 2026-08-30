# Custom prerequisite target before a tiny static component.

buildmaster_prerequisite(prereq_touch
	COMMAND ${CMAKE_COMMAND} -E touch
		"${CMAKE_CURRENT_BINARY_DIR}/prereq.stamp"
	COMMENT "Harness prerequisite touch"
)

_bm_backend_cmake_create(
	prereq-lib
	"Harness prerequisite consumer"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	""
	static
	"prereqlib"
)
buildmaster_depend(prereq-lib prereq_touch)
