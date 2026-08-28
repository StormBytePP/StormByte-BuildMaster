add_subdirectory(buildmaster)
include(buildmaster/helpers.cmake)

add_subdirectory(dep)

add_dependencies(consumer_host consumer-dep_install)
target_link_libraries(consumer_host PRIVATE consumer-dep)
