_bm_backend_cmake_create(
	dup-a
	"Harness dup A"
	"${CMAKE_CURRENT_SOURCE_DIR}/a"
	""
	static
	"dupalib"
)
_bm_backend_cmake_create(
	dup-b
	"Harness dup B"
	"${CMAKE_CURRENT_SOURCE_DIR}/b"
	""
	static
	"dupblib"
)

buildmaster_link(dup-a dup-b)
buildmaster_link(dup-a dup-b)
buildmaster_depend(dup-a dup-b)
