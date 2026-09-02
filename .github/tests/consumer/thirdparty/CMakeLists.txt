# In-tree consumer: BM is the repo root (thirdparty → consumer → tests →
# .github → root). Do not use a git symlink named buildmaster: on Windows
# checkout that entry is often a text file or Permission denied.
get_filename_component(_BM_CONSUMER_ROOT
	"${CMAKE_CURRENT_SOURCE_DIR}/../../../.."
	ABSOLUTE
)
add_subdirectory("${_BM_CONSUMER_ROOT}" "${CMAKE_CURRENT_BINARY_DIR}/buildmaster")
include("${_BM_CONSUMER_ROOT}/helpers.cmake")
add_subdirectory(dep)
