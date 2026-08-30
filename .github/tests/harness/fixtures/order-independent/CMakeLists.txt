# Intentionally reverse declaration order:
# dependency edge and dependent component before the prerequisite.

buildmaster_depend(second first)
buildmaster_link(second first)

_bm_backend_cmake_create(
	second
	"Order-independent dependent"
	"${CMAKE_CURRENT_SOURCE_DIR}/second"
	""
	static
	"secondlib"
)

_bm_backend_cmake_create(
	first
	"Order-independent prerequisite"
	"${CMAKE_CURRENT_SOURCE_DIR}/first"
	""
	static
	"firstlib"
)

add_executable(order_independent_link_test
	"${CMAKE_CURRENT_SOURCE_DIR}/order_independent_link_test.c"
)
target_link_libraries(order_independent_link_test PRIVATE second)
