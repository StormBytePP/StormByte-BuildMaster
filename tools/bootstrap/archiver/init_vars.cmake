if(NOT BUILDMASTER_TOOLS_ARCHIVER_SRCDIR)
	set(BUILDMASTER_TOOLS_ARCHIVER_SRCDIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL
		"tools/bootstrap/archiver source dir")
	include("${CMAKE_CURRENT_LIST_DIR}/helpers.cmake")
	_bm_tools_archiver_find(BUILDMASTER_TOOLS_ARCHIVER BUILDMASTER_TOOLS_ARCHIVER_STYLE)
	set(BUILDMASTER_TOOLS_ARCHIVER "${BUILDMASTER_TOOLS_ARCHIVER}" CACHE FILEPATH
		"static archiver" FORCE)
	set(BUILDMASTER_TOOLS_ARCHIVER_STYLE "${BUILDMASTER_TOOLS_ARCHIVER_STYLE}" CACHE INTERNAL
		"msvc_lib or gnu_ar")
	set(CMAKE_AR "${BUILDMASTER_TOOLS_ARCHIVER}" CACHE FILEPATH "archiver" FORCE)

	if(BUILDMASTER_TOOLS_ARCHIVER_STYLE STREQUAL "gnu_ar")
		get_filename_component(_ar_dir "${BUILDMASTER_TOOLS_ARCHIVER}" DIRECTORY)
		find_program(_bm_ranlib NAMES llvm-ranlib gcc-ranlib ranlib
			HINTS "${_ar_dir}")
		if(_bm_ranlib)
			set(CMAKE_RANLIB "${_bm_ranlib}" CACHE FILEPATH "ranlib" FORCE)
		endif()
	endif()

	include("${CMAKE_CURRENT_LIST_DIR}/update_toolchain.cmake")
endif()
