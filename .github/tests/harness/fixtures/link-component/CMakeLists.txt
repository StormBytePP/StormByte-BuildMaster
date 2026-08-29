# buildmaster_link to another component (not a library-spec path).

_bm_path_builddir(LINK_A_BUILD "link-a")
_bm_comp_cmake_create(
	link-a
	"Harness link-a"
	"${CMAKE_CURRENT_SOURCE_DIR}/a"
	"${LINK_A_BUILD}"
	""
	static
	"alinklib"
)

_bm_path_builddir(LINK_B_BUILD "link-b")
_bm_comp_cmake_create(
	link-b
	"Harness link-b"
	"${CMAKE_CURRENT_SOURCE_DIR}/b"
	"${LINK_B_BUILD}"
	""
	static
	"blinklib"
)

buildmaster_depend(link-b link-a)
buildmaster_link(link-b link-a)

add_executable(link_component_test
	"${CMAKE_CURRENT_SOURCE_DIR}/link_component_test.c"
)
target_link_libraries(link_component_test PRIVATE link-b)