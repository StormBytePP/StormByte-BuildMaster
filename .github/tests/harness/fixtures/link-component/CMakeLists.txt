# component_link to another component (not a library-spec path).

ensure_build_dir(LINK_A_BUILD "link-a")
create_cmake_component(
	link-a
	"Harness link-a"
	"${CMAKE_CURRENT_SOURCE_DIR}/a"
	"${LINK_A_BUILD}"
	""
	static
	"alinklib"
)

ensure_build_dir(LINK_B_BUILD "link-b")
create_cmake_component(
	link-b
	"Harness link-b"
	"${CMAKE_CURRENT_SOURCE_DIR}/b"
	"${LINK_B_BUILD}"
	""
	static
	"blinklib"
)

component_dependency(link-b link-a)
component_link(link-b link-a)

add_executable(link_component_test
	"${CMAKE_CURRENT_SOURCE_DIR}/link_component_test.c"
)
target_link_libraries(link_component_test PRIVATE link-b)