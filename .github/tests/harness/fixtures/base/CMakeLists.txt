ensure_build_dir(BASE_BUILD_DIR "base")
create_cmake_component(
	BASE_FILE
	base
	"Harness base library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${BASE_BUILD_DIR}"
	""
	static
	"baselib"
)
include("${BASE_FILE}")