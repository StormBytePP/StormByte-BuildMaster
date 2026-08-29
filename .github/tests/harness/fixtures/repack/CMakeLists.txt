# BUILDONLY phases → meta REPACK → link all symbols from the merge.

set(_ra_src "${CMAKE_CURRENT_SOURCE_DIR}/phase_a")
set(_ra_build "${CMAKE_CURRENT_BINARY_DIR}/phase_a_build")
file(MAKE_DIRECTORY "${_ra_build}")

set(_rb_src "${CMAKE_CURRENT_SOURCE_DIR}/phase_b")
set(_rb_build "${CMAKE_CURRENT_BINARY_DIR}/phase_b_build")
file(MAKE_DIRECTORY "${_rb_build}")

_bm_backend_cmake_create(
	repack-a
	"Harness repack phase A"
	"${_ra_src}"
	"${_ra_build}"
	""
	static
	"alib;aextra"
	"BUILDONLY"
)

_bm_backend_cmake_create(
	repack-b
	"Harness repack phase B"
	"${_rb_src}"
	"${_rb_build}"
	""
	static
	"blib"
	"BUILDONLY"
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
