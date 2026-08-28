cmake_minimum_required(VERSION 3.20)
project(BuildMasterConsumer LANGUAGES C)

# Linking an executable in this directory to a target declared in
# thirdparty/ requires CMP0079 NEW (targets from other directories).
cmake_policy(SET CMP0079 NEW)

add_subdirectory(lib)
add_subdirectory(thirdparty)

# Logger-style namespaced ALIAS. create_component must have declared
# the INTERFACE stub already; otherwise this is a hard configure error
# and the regression cannot slip through.
add_library(Consumer::Dep ALIAS consumer-dep)

target_link_libraries(consumer_host PRIVATE Consumer::Dep)
