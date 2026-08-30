# Private headers (no backend) + a cmake consumer that #includes them.
# Sibling has no link edge: its sources must not see priv.h.

_bm_path_builddir(PRIV_H_BUILDDIR)
_bm_path_builddir(PRIV_CONSUMER_BUILDDIR)

buildmaster_component(
    priv-h
    "Harness private headers"
    "${CMAKE_CURRENT_SOURCE_DIR}/tree"
    "${PRIV_H_BUILDDIR}"
    ""
    headers
    ""
)

buildmaster_component(
    priv-consumer
    "Harness private-headers consumer"
    "${CMAKE_CURRENT_SOURCE_DIR}/consumer"
    "${PRIV_CONSUMER_BUILDDIR}"
    ""
    static
    "privconsumer"
)

buildmaster_link(priv-consumer priv-h)
