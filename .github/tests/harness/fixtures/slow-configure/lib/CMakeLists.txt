cmake_minimum_required(VERSION 3.20)
project(bm_slow_configure LANGUAGES C)

include(GNUInstallDirs)

message(STATUS "slow-configure: sleeping 5s (start)")
execute_process(COMMAND "${CMAKE_COMMAND}" -E sleep 5)
message(STATUS
	"slow-configure: sleeping 5s (done) — "
	"you should have seen 'Configuring Harness slow configure' BEFORE this line; "
	"if it appears only now, COMMENT is too late and _configure needs echo")

add_library(slowlib STATIC slow.c)
target_include_directories(slowlib PUBLIC
	$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
	$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
install(TARGETS slowlib
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install(FILES slow.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
