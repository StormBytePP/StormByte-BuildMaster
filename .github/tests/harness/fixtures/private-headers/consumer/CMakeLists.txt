cmake_minimum_required(VERSION 3.20)
project(priv_consumer C)

include(GNUInstallDirs)

add_library(privconsumer STATIC consumer.c)

install(TARGETS privconsumer
	ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
	LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
