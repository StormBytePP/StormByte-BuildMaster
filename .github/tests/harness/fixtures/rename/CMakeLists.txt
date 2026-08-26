# Meson installs zs.* ; produced is z.* → post-install RENAME must fix it.

ensure_build_dir(RENAME_VARIANT_BUILD_DIR "rename-variant")
create_meson_component(
	rename-variant
	"Harness rename variant library"
	"${CMAKE_CURRENT_SOURCE_DIR}/lib"
	"${RENAME_VARIANT_BUILD_DIR}"
	""
	static
	"z"
	# RENAME defaults ON; explicit for fixture intent
	"RENAME"
)

add_executable(rename_variant_link_test
	"${CMAKE_CURRENT_SOURCE_DIR}/rename_variant_link_test.c"
)
target_link_libraries(rename_variant_link_test PRIVATE rename-variant)
