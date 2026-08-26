ensure_build_dir(DEP_BUILD_DIR "dep")
create_cmake_component(
	dep
	"Harness dependant library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${DEP_BUILD_DIR}"
	""
	static
	"deplib"
)
component_dependency(dep base)
