ensure_build_dir(BASE_BUILD_DIR "base")
create_cmake_component(
	base
	"Harness base library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${BASE_BUILD_DIR}"
	""
	static
	"baselib"
)