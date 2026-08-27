# Nested meta: add members before create_meta_component (lazy id).
# meta-inner → leaf-a + leaf-b; meta-plugins WHOLE wraps those statics.
# meta-out is a normal BM lib kept outside the whole-archive region.
# Host consumes only meta-plugins + meta-out.

set(_a_src "${CMAKE_CURRENT_SOURCE_DIR}/leaf_a")
set(_b_src "${CMAKE_CURRENT_SOURCE_DIR}/leaf_b")
set(_a_build "${CMAKE_CURRENT_BINARY_DIR}/leaf_a_build")
set(_b_build "${CMAKE_CURRENT_BINARY_DIR}/leaf_b_build")
set(_out_src "${CMAKE_CURRENT_SOURCE_DIR}/out")
set(_out_build "${CMAKE_CURRENT_BINARY_DIR}/out_build")
file(MAKE_DIRECTORY "${_a_build}" "${_b_build}" "${_out_build}")

meta_component_add(meta-inner leaf-a)
meta_component_add(meta-inner leaf-b)
meta_component_add(meta-plugins meta-inner)

create_cmake_component(
	leaf-a
	"Harness meta leaf A"
	"${_a_src}"
	"${_a_build}"
	""
	static
	"metaleafa"
)

create_cmake_component(
	leaf-b
	"Harness meta leaf B"
	"${_b_src}"
	"${_b_build}"
	""
	static
	"metaleafb"
)

create_cmake_component(
	meta-out
	"Harness meta outside library"
	"${_out_src}"
	"${_out_build}"
	""
	static
	"metaout"
)

create_meta_component(meta-inner "Harness nested meta")
create_meta_component(meta-plugins "Harness plugin meta" "WHOLE")

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
