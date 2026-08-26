# Custom prerequisite target before a tiny static component.

component_prerequisite(prereq_touch
	COMMAND ${CMAKE_COMMAND} -E touch
		"${CMAKE_CURRENT_BINARY_DIR}/prereq.stamp"
	COMMENT "Harness prerequisite touch"
)

ensure_build_dir(PREREQ_LIB_BUILD_DIR "prereq-lib")
create_cmake_component(
	prereq-lib
	"Harness prerequisite consumer"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${PREREQ_LIB_BUILD_DIR}"
	""
	static
	"prereqlib"
)
component_dependency(prereq-lib prereq_touch)