ensure_build_dir(_slow_build "slow-configure")
create_cmake_component(
	slow-configure
	"Harness slow configure"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${_slow_build}"
	""
	static
	"slowlib"
)
# Force build-time configure so Ninja prints the status line.
component_dependency(slow-configure base)
