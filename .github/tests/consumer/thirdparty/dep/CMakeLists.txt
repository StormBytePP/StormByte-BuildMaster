ensure_build_dir(CONSUMERDEP_BUILDDIR)

create_cmake_component(
	consumer-dep
	"Consumer-style dependant library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${CONSUMERDEP_BUILDDIR}"
	""
	"static"
	"consumerdep"
	"INDENT=1"
)
