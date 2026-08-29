_bm_path_builddir(BASE_BUILD_DIR "base")
_bm_backend_cmake_create(
	base
	"Harness base library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${BASE_BUILD_DIR}"
	""
	static
	"baselib"
)