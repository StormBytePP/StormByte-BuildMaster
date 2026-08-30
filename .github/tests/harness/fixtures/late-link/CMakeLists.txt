# dest is created AFTER the link. The edge must still defer src configure.

_bm_backend_cmake_create(
	late-src
	"Harness late-link source"
	"${CMAKE_CURRENT_SOURCE_DIR}/src"
	""
	static
	"latesrclib"
)

buildmaster_link(late-src late-dst)

_bm_backend_cmake_create(
	late-dst
	"Harness late-link dest"
	"${CMAKE_CURRENT_SOURCE_DIR}/dst"
	""
	static
	"latedstlib"
)
