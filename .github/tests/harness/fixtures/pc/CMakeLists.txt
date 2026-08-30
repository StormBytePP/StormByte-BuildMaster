# Helper .pc for internal BM consumers (Requires follows buildmaster_link).

_bm_backend_cmake_create(
	pc-dep
	"Harness PC dependency"
	"${CMAKE_CURRENT_SOURCE_DIR}/dep"
	""
	static
	"pcdeplib"
	"PC={VERSION=1.0.0;NAME=pcdep}"
)

_bm_backend_cmake_create(
	pc-lib
	"Harness PC library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	""
	static
	"pclib"
	"PC={VERSION=2.0.0;NAME=pclib}"
)

buildmaster_link(pc-lib pc-dep)

add_custom_target(pc_check_run
	COMMAND ${CMAKE_COMMAND}
		-DDEP_PC=${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/pcdep.pc
		-DLIB_PC=${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/pclib.pc
		-P ${CMAKE_CURRENT_SOURCE_DIR}/check_pc.cmake
	COMMENT "[BuildMaster/Core     ]: check helper .pc Requires"
	DEPENDS pc-dep_install pc-lib_install
	VERBATIM
)
