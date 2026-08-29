_bm_log_message(ENV STATUS "Setting up environment..." 1)

# Set up environment runner scripts
include(init_vars.cmake)

# Propagate environment variables to parent scope
include(propagate_vars.cmake)