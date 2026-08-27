# Helper .pc for internal BM consumers (Requires follows component_link).

ensure_build_dir(PC_DEP_BUILD "pc-dep")
create_cmake_component(
	pc-dep
	"Harness PC dependency"
	"${CMAKE_CURRENT_SOURCE_DIR}/dep"
	"${PC_DEP_BUILD}"
	""
	static
	"pcdeplib"
	"PC={VERSION=1.0.0;NAME=pcdep}"
)

ensure_build_dir(PC_LIB_BUILD "pc-lib")
create_cmake_component(
	pc-lib
	"Harness PC library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${PC_LIB_BUILD}"
	""
	static
	"pclib"
	"PC={VERSION=2.0.0;NAME=pclib}"
)

component_link(pc-lib pc-dep)

add_custom_target(pc_check_run
	COMMAND ${CMAKE_COMMAND}
		-DDEP_PC=${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/pcdep.pc
		-DLIB_PC=${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/pclib.pc
		-P ${CMAKE_CURRENT_SOURCE_DIR}/check_pc.cmake
	COMMENT "[BuildMaster/Core     ]: check helper .pc Requires"
	DEPENDS pc-dep_install pc-lib_install
	VERBATIM
)
