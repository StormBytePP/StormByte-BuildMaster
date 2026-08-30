# Private headers (no backend) + a cmake consumer that #includes them.
# Sibling has no link edge: its sources must not see priv.h.

buildmaster_component(
	priv-h
	"Harness private headers"
	"${CMAKE_CURRENT_SOURCE_DIR}/tree"
	""
	headers
	""
)

buildmaster_component(
	priv-consumer
	"Harness private-headers consumer"
	"${CMAKE_CURRENT_SOURCE_DIR}/consumer"
	""
	static
	"privconsumer"
)

buildmaster_link(priv-consumer priv-h)
