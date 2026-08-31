cmake_minimum_required(VERSION 3.28)
project(SharedLogger-src C)
include(GNUInstallDirs)

set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

add_library(SharedLogger SHARED logger.c)
target_include_directories(SharedLogger PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(SharedLogger PUBLIC SharedBase)
install(TARGETS SharedLogger
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
install(FILES shared_logger.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
