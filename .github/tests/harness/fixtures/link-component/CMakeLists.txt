# buildmaster_link to another component (not a library-spec path).

_bm_backend_cmake_create(
	link-a
	"Harness link-a"
	"${CMAKE_CURRENT_SOURCE_DIR}/a"
	""
	static
	"alinklib"
)

_bm_backend_cmake_create(
	link-b
	"Harness link-b"
	"${CMAKE_CURRENT_SOURCE_DIR}/b"
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
