# Outline groups: banners + walk order. No targets on the group itself.
# plugins
#     Audio
#         Opus
#         Speex
#     Filters
#         VMAF
#         SSIM
# leftover (ungrouped) after the tree

buildmaster_component(
	grp-opus
	"Opus codec"
	"${CMAKE_CURRENT_SOURCE_DIR}/opus"
	""
	static
	"grpopus"
)
buildmaster_component(
	grp-speex
	"Speex codec"
	"${CMAKE_CURRENT_SOURCE_DIR}/speex"
	""
	static
	"grpspeex"
)
buildmaster_component(
	grp-vmaf
	"VMAF filter"
	"${CMAKE_CURRENT_SOURCE_DIR}/vmaf"
	""
	static
	"grpvmaf"
)
buildmaster_component(
	grp-ssim
	"SSIM filter"
	"${CMAKE_CURRENT_SOURCE_DIR}/ssim"
	""
	static
	"grpssim"
)
buildmaster_component(
	grp-orphan
	"Ungrouped leftover"
	"${CMAKE_CURRENT_SOURCE_DIR}/orphan"
	""
	static
	"grporphan"
)

buildmaster_group(grp-plugins "FFmpeg plugins")
buildmaster_group(grp-audio "Audio")
buildmaster_group(grp-filters "Filters")
buildmaster_group_add(grp-plugins grp-audio grp-filters)
buildmaster_group_add(grp-audio grp-opus grp-speex)
buildmaster_group_add(grp-filters grp-vmaf grp-ssim)
