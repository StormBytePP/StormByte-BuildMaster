ensure_build_dir(HEADERS_BUILD_DIR "sdk-headers")
create_cmake_headers_component(
	sdk-headers
	"Harness SDK headers"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${HEADERS_BUILD_DIR}"
	""
)