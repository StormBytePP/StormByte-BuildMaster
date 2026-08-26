# Internal: ordered archive name variants (earlier = preferred).
# Edit only this list to teach the normalizer new upstream naming patterns.
# Empty string = exact stem (usually already handled by EXISTS on the canonical path).

set(BUILDMASTER_RENAME_VARIANTS
	""
	"s"
	"static"
	"-static"
	"_static"
	"d"
	"sd"
	"-debug"
	"_debug"
	"debug"
)