cmake_minimum_required(VERSION 3.20)
project(headers_only LANGUAGES NONE)

include(GNUInstallDirs)

install(FILES sdk.h DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})