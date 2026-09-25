# group_add before buildmaster_group. The outline is still:
# late-outer
#     late-inner
#         late-leaf

buildmaster_group_add(late-outer late-inner)
buildmaster_group_add(late-inner late-leaf)

buildmaster_component(
	late-leaf
	"Late leaf"
	"${CMAKE_CURRENT_SOURCE_DIR}/leaf"
	""
	static
	"lateleaf"
)

buildmaster_group(late-inner "Late inner")
buildmaster_group(late-outer "Late outer")
