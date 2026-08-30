# Nested meta: add members before buildmaster_meta (lazy id).
# meta-inner → leaf-a + leaf-b; meta-plugins WHOLE wraps those statics.
# meta-out is a normal BM lib kept outside the whole-archive region.
# Host consumes only meta-plugins + meta-out.

set(_a_src "${CMAKE_CURRENT_SOURCE_DIR}/leaf_a")
set(_b_src "${CMAKE_CURRENT_SOURCE_DIR}/leaf_b")
set(_out_src "${CMAKE_CURRENT_SOURCE_DIR}/out")

buildmaster_meta_add(meta-inner leaf-a)
buildmaster_meta_add(meta-inner leaf-b)
buildmaster_meta_add(meta-plugins meta-inner)

_bm_backend_cmake_create(
	leaf-a
	"Harness meta leaf A"
	"${_a_src}"
	""
	static
	"metaleafa"
)

_bm_backend_cmake_create(
	leaf-b
	"Harness meta leaf B"
	"${_b_src}"
	""
	static
	"metaleafb"
)

_bm_backend_cmake_create(
	meta-out
	"Harness meta outside library"
	"${_out_src}"
	""
	static
	"metaout"
)

buildmaster_meta(meta-inner "Harness nested meta")
buildmaster_meta(meta-plugins "Harness plugin meta" "WHOLE")

add_executable(meta_link_test meta_link_test.c)
target_include_directories(meta_link_test PRIVATE
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
target_link_libraries(meta_link_test PRIVATE meta-plugins meta-out)
add_dependencies(meta_link_test meta-plugins_install meta-out_install)

add_custom_target(meta_link_test_run
	COMMAND $<TARGET_FILE:meta_link_test>
	DEPENDS meta_link_test
	COMMENT "[BuildMaster/Core     ]: run meta_link_test (WHOLE nested meta + outside; expect 0)"
)
