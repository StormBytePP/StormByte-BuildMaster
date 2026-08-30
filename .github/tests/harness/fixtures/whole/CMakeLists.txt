# whole-lib:  WHOLE → closed whole-archive region on its produced statics only.
# plain-lib:  same sources, no WHOLE (produced wlibplain — distinct prefix name).
# out-lib:    normal BM static; must appear outside any whole-archive region.
# Host links BM INTERFACE targets only.

set(_w_src "${CMAKE_CURRENT_SOURCE_DIR}/lib")
set(_o_src "${CMAKE_CURRENT_SOURCE_DIR}/out")

_bm_backend_cmake_create(
	whole-lib
	"Harness WHOLE static library"
	"${_w_src}"
	"-DHARNESS_WLIB_OUTPUT_NAME=wlib"
	static
	"wlib"
	"WHOLE"
)

_bm_backend_cmake_create(
	plain-lib
	"Harness plain static library (no WHOLE)"
	"${_w_src}"
	"-DHARNESS_WLIB_OUTPUT_NAME=wlibplain"
	static
	"wlibplain"
)

_bm_backend_cmake_create(
	out-lib
	"Harness WHOLE outside library"
	"${_o_src}"
	""
	static
	"outlib"
)

add_executable(whole_link_test whole_link_test.c)
target_include_directories(whole_link_test PRIVATE
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
target_link_libraries(whole_link_test PRIVATE whole-lib out-lib)
add_dependencies(whole_link_test whole-lib_install out-lib_install)

add_custom_target(whole_link_test_run
	COMMAND $<TARGET_FILE:whole_link_test>
	DEPENDS whole_link_test
	COMMENT "Run whole_link_test (WHOLE + outlib; expect exit 0)"
)

add_executable(whole_link_test_nowhole whole_link_test.c)
target_include_directories(whole_link_test_nowhole PRIVATE
	"${BUILDMASTER_INSTALL_INCLUDEDIR}"
)
target_link_libraries(whole_link_test_nowhole PRIVATE plain-lib out-lib)
add_dependencies(whole_link_test_nowhole plain-lib_install out-lib_install)

add_custom_target(whole_link_test_nowhole_run
	COMMAND ${CMAKE_COMMAND}
		"-DEXE=$<TARGET_FILE:whole_link_test_nowhole>"
		-P "${CMAKE_CURRENT_SOURCE_DIR}/expect_nonzero.cmake"
	DEPENDS whole_link_test_nowhole
	COMMENT "[BuildMaster/Core     ]: run whole_link_test_nowhole (no WHOLE; expect non-zero)"
)
