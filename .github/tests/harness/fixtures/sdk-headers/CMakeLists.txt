_bm_path_builddir(HEADERS_BUILD_DIR "sdk-headers")
_bm_comp_cmake_create_headers(
	sdk-headers
	"Harness SDK headers"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${HEADERS_BUILD_DIR}"
	""
)