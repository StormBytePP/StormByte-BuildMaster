# NOINSTALL phases → meta REPACK → link all symbols from the merge.

set(_ra_src "${CMAKE_CURRENT_SOURCE_DIR}/phase_a")
set(_rb_src "${CMAKE_CURRENT_SOURCE_DIR}/phase_b")

_bm_backend_cmake_create(
	repack-a
	"Harness repack phase A"
	"${_ra_src}"
	""
	static
	"alib;aextra"
	"NOINSTALL"
)

_bm_backend_cmake_create(
	repack-b
	"Harness repack phase B"
	"${_rb_src}"
	""
	static
	"blib"
	"NOINSTALL"
)

buildmaster_meta(mergedlib "Harness repack merge" "REPACK")
buildmaster_meta_add(mergedlib repack-a repack-b)

add_executable(repack_link_test repack_link_test.c)
target_include_directories(repack_link_test PRIVATE
	"${CMAKE_CURRENT_SOURCE_DIR}/phase_a"
	"${CMAKE_CURRENT_SOURCE_DIR}/phase_b"
)
target_link_libraries(repack_link_test PRIVATE mergedlib)
add_dependencies(repack_link_test mergedlib_install)
