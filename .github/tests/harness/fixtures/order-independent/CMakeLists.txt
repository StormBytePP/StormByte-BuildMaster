# Intentionally reverse declaration order:
# dependency edge and dependent component before the prerequisite.

component_dependency(second first)
component_link(second first)

ensure_build_dir(SECOND_BUILD_DIR "second")
create_cmake_component(
	second
	"Order-independent dependent"
	"${CMAKE_CURRENT_SOURCE_DIR}/second"
	"${SECOND_BUILD_DIR}"
	""
	static
	"secondlib"
)

ensure_build_dir(FIRST_BUILD_DIR "first")
create_cmake_component(
	first
	"Order-independent prerequisite"
	"${CMAKE_CURRENT_SOURCE_DIR}/first"
	"${FIRST_BUILD_DIR}"
	""
	static
	"firstlib"
)

add_executable(order_independent_link_test
	"${CMAKE_CURRENT_SOURCE_DIR}/order_independent_link_test.c"
)
target_link_libraries(order_independent_link_test PRIVATE second)