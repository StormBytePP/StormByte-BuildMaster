# Intentionally reverse declaration order:
# dependency edge and dependent component before the prerequisite.

buildmaster_depend(second first)
buildmaster_link(second first)

_bm_path_builddir(SECOND_BUILD_DIR "second")
_bm_comp_cmake_create(
	second
	"Order-independent dependent"
	"${CMAKE_CURRENT_SOURCE_DIR}/second"
	"${SECOND_BUILD_DIR}"
	""
	static
	"secondlib"
)

_bm_path_builddir(FIRST_BUILD_DIR "first")
_bm_comp_cmake_create(
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