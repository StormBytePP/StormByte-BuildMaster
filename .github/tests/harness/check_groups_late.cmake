# groups-late: group_add ran before either buildmaster_group.
# The walk must still be outer → inner → leaf at indent 2.

get_property(_gids GLOBAL PROPERTY BUILDMASTER_GROUP_IDS)
foreach(_need IN ITEMS late-outer late-inner)
	list(FIND _gids "${_need}" _idx)
	if(_idx EQUAL -1)
		_bm_log_message(CORE FATAL
			"groups-late: missing group id '${_need}'")
	endif()
endforeach()

get_property(_ev GLOBAL PROPERTY BUILDMASTER_GROUP_EVENTS)
string(FIND "${_ev}" "banner:late-outer:0;banner:late-inner:1;comp:late-leaf" _hit)
if(_hit LESS 0)
	_bm_log_message(CORE FATAL
		"groups-late: outline missing from events: ${_ev}")
endif()

get_property(_ind GLOBAL PROPERTY BUILDMASTER_COMPONENT_late-leaf_INDENT)
if(NOT _ind STREQUAL "2")
	_bm_log_message(CORE FATAL
		"groups-late: late-leaf INDENT '${_ind}' (want 2)")
endif()

_bm_log_message(CORE STATUS "groups-late: add-before-create OK")
