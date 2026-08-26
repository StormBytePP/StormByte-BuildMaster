ensure_build_dir(DEP_BUILD_DIR "dep")
create_cmake_dependant_component(
	DEP_FILE
	dep
	"Harness dependant library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${DEP_BUILD_DIR}"
	""
	static
	"deplib"
	"base_install"
)
include("${DEP_FILE}")