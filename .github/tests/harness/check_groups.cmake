# Event list is the visual contract:
#   banner:grp-plugins:0
#   banner:grp-audio:1
#   comp:grp-opus
#   comp:grp-speex
#   banner:grp-filters:1
#   comp:grp-vmaf
#   comp:grp-ssim
# then leftover comps (grp-orphan among them).

get_property(_gids GLOBAL PROPERTY BUILDMASTER_GROUP_IDS)
foreach(_need IN ITEMS grp-plugins grp-audio grp-filters)
	list(FIND _gids "${_need}" _idx)
	if(_idx EQUAL -1)
		_bm_log_message(CORE FATAL
			"groups: missing group id '${_need}'")
	endif()
endforeach()

get_property(_ev GLOBAL PROPERTY BUILDMASTER_GROUP_EVENTS)
if(NOT _ev)
	_bm_log_message(CORE FATAL "groups: empty BUILDMASTER_GROUP_EVENTS")
endif()

list(LENGTH _ev _n)
if(_n LESS 7)
	_bm_log_message(CORE FATAL
		"groups: event list too short (${_n}): ${_ev}")
endif()

list(GET _ev 0 _e0)
list(GET _ev 1 _e1)
list(GET _ev 2 _e2)
list(GET _ev 3 _e3)
list(GET _ev 4 _e4)
list(GET _ev 5 _e5)
list(GET _ev 6 _e6)
set(_want0 "banner:grp-plugins:0")
set(_want1 "banner:grp-audio:1")
set(_want2 "comp:grp-opus")
set(_want3 "comp:grp-speex")
set(_want4 "banner:grp-filters:1")
set(_want5 "comp:grp-vmaf")
set(_want6 "comp:grp-ssim")
if(NOT _e0 STREQUAL "${_want0}"
		OR NOT _e1 STREQUAL "${_want1}"
		OR NOT _e2 STREQUAL "${_want2}"
		OR NOT _e3 STREQUAL "${_want3}"
		OR NOT _e4 STREQUAL "${_want4}"
		OR NOT _e5 STREQUAL "${_want5}"
		OR NOT _e6 STREQUAL "${_want6}")
	_bm_log_message(CORE FATAL
		"groups: outline prefix '${_e0};${_e1};${_e2};${_e3};${_e4};${_e5};${_e6}' != '${_want0};${_want1};${_want2};${_want3};${_want4};${_want5};${_want6}'")
endif()

list(FIND _ev "comp:grp-orphan" _i_orph)
if(_i_orph LESS 7)
	_bm_log_message(CORE FATAL
		"groups: grp-orphan should follow the outline prefix (index ${_i_orph})")
endif()

get_property(_iop GLOBAL PROPERTY BUILDMASTER_COMPONENT_grp-opus_INDENT)
get_property(_isp GLOBAL PROPERTY BUILDMASTER_COMPONENT_grp-speex_INDENT)
get_property(_ivm GLOBAL PROPERTY BUILDMASTER_COMPONENT_grp-vmaf_INDENT)
get_property(_iss GLOBAL PROPERTY BUILDMASTER_COMPONENT_grp-ssim_INDENT)
if(NOT _iop STREQUAL "2" OR NOT _isp STREQUAL "2"
		OR NOT _ivm STREQUAL "2" OR NOT _iss STREQUAL "2")
	_bm_log_message(CORE FATAL
		"groups: member INDENT opus='${_iop}' speex='${_isp}' vmaf='${_ivm}' ssim='${_iss}' (want 2)")
endif()

_bm_log_message(CORE STATUS "groups: outline events OK")
