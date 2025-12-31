message(STATUS "Bootstrapping StormByte-BuildEngine (https://github.com/StormBytePP/StormByte-BuildEngine)")

# Initialize directory variables
include(init_vars.cmake)

# Include helpers
include(helpers.cmake)

# Configure environment components and propagate variables
add_subdirectory(env)
include(env/propagate_vars.cmake)

# Configure build tools and propagate variables
add_subdirectory(tools)
include(tools/propagate_vars.cmake)

# Propagate variables to parent scope
include(propagate_vars.cmake)
