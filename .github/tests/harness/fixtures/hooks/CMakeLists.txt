# Hooks fire during harness finalize (explicit _buildmaster_finalize_components).
# Alias order is the only contract: aa-* before zz-*.

set(HOOK_STAMP "${CMAKE_BINARY_DIR}/harness_hooks.stamp")
file(WRITE "${HOOK_STAMP}" "")

function(hook_mat_aa)
    file(APPEND "${HOOK_STAMP}" "aa-mat:${HOOK_WHICH}\n")
endfunction()

function(hook_mat_zz)
    file(APPEND "${HOOK_STAMP}" "zz-mat:${HOOK_WHICH}\n")
endfunction()

function(hook_graph_aa)
    file(APPEND "${HOOK_STAMP}" "aa-graph\n")
endfunction()

function(hook_graph_zz)
    file(APPEND "${HOOK_STAMP}" "zz-graph\n")
endfunction()

create_cmake_component(
    hook-a
    "Harness hook A"
    "${CMAKE_CURRENT_SOURCE_DIR}/lib-a"
    "${CMAKE_CURRENT_BINARY_DIR}/hook-a"
    ""
    static
    "hookalib"
)

create_cmake_component(
    hook-b
    "Harness hook B"
    "${CMAKE_CURRENT_SOURCE_DIR}/lib-b"
    "${CMAKE_CURRENT_BINARY_DIR}/hook-b"
    ""
    static
    "hookblib"
)

# Register zz first on purpose. Execution must still be aa then zz.
set(HOOK_WHICH "a")
buildmaster_on_component_materialize(hook-a hook_mat_zz zz-mat
    CAPTURE HOOK_STAMP HOOK_WHICH
)
buildmaster_on_component_materialize(hook-a hook_mat_aa aa-mat
    CAPTURE HOOK_STAMP HOOK_WHICH
)

set(HOOK_WHICH "b")
buildmaster_on_component_materialize(hook-b hook_mat_aa aa-mat
    CAPTURE HOOK_STAMP HOOK_WHICH
)

buildmaster_on_graph_finalized(hook_graph_zz zz-graph
    CAPTURE HOOK_STAMP
)
buildmaster_on_graph_finalized(hook_graph_aa aa-graph
    CAPTURE HOOK_STAMP
)
