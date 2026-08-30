include("${CMAKE_CURRENT_LIST_DIR}/../../../log.cmake")
if(COMMAND _bm_log_level_init)
	_bm_log_level_init()
endif()

## @brief Whether any list item contains `token` as a substring.
function(_bm_lf_contains items token out_var)
	set(_hit FALSE)
	foreach(_it IN LISTS items)
		string(FIND "${_it}" "${token}" _pos)
		if(NOT _pos EQUAL -1)
			set(_hit TRUE)
			break()
		endif()
	endforeach()
	set(${out_var} "${_hit}" PARENT_SCOPE)
endfunction()

## @brief Assert a token is / is not folded into component OPTIONS.
## @note LINKFLAGS live in `-DCMAKE_*_LINKER_FLAGS=` (cmake) after
##       `_bm_materialize_inject_linkflags`. Not on INTERFACE.
function(_bm_lf_expect_options id token should_have)
	get_property(_opts GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_OPTIONS)
	if(NOT _opts)
		set(_opts "")
	endif()
	_bm_lf_contains("${_opts}" "${token}" _has)
	if(should_have AND NOT _has)
		_bm_log_message(CORE FATAL
			"LINKFLAGS: '${id}' OPTIONS missing '${token}' (have: ${_opts})")
	endif()
	if(NOT should_have AND _has)
		_bm_log_message(CORE FATAL
			"LINKFLAGS: '${id}' OPTIONS must not carry '${token}' on this host (have: ${_opts})")
	endif()
endfunction()

## @brief Assert a token is / is not on INTERFACE_LINK_OPTIONS.
## @note After the LINKFLAGS contract change this must stay empty of
##       those flags: they must not leak to consumers.
function(_bm_lf_expect_iface tgt token should_have)
	if(NOT TARGET "${tgt}")
		_bm_log_message(CORE FATAL "LINKFLAGS check: target '${tgt}' does not exist")
	endif()
	get_target_property(_opts "${tgt}" INTERFACE_LINK_OPTIONS)
	if(_opts STREQUAL "_opts-NOTFOUND" OR NOT _opts)
		set(_opts "")
	endif()
	_bm_lf_contains("${_opts}" "${token}" _has)
	if(should_have AND NOT _has)
		_bm_log_message(CORE FATAL
			"LINKFLAGS: '${tgt}' INTERFACE missing '${token}' (have: ${_opts})")
	endif()
	if(NOT should_have AND _has)
		_bm_log_message(CORE FATAL
			"LINKFLAGS: '${tgt}' INTERFACE must not carry '${token}' (have: ${_opts})")
	endif()
endfunction()

foreach(_t lf-os lf-unix lf-os-meta lf-unix-meta)
	if(NOT TARGET "${_t}")
		_bm_log_message(CORE FATAL "LINKFLAGS fixture '${_t}' was not materialized")
	endif()
endforeach()

set(_win "/ALTERNATENAME:bm_lf_ok=__ImageBase")
set(_linux "-Wl,--defsym,bm_lf_ok=1")
set(_mac "-Wl,-alias,__mh_execute_header,_bm_lf_ok")
set(_unix "-Wl,-rpath,/bm-harness-unix")

# No leak on the component or meta INTERFACE (any host).
foreach(_tok IN ITEMS "${_win}" "${_linux}" "${_mac}" "${_unix}")
	_bm_lf_expect_iface(lf-os "${_tok}" FALSE)
	_bm_lf_expect_iface(lf-unix "${_tok}" FALSE)
	_bm_lf_expect_iface(lf-os-meta "${_tok}" FALSE)
	_bm_lf_expect_iface(lf-unix-meta "${_tok}" FALSE)
endforeach()

# Meta LINKFLAGS is WARNING + ignored: no OPTIONS to fold into.
foreach(_tok IN ITEMS "${_win}" "${_linux}" "${_mac}" "${_unix}")
	_bm_lf_expect_options(lf-os-meta "${_tok}" FALSE)
	_bm_lf_expect_options(lf-unix-meta "${_tok}" FALSE)
endforeach()

if(WIN32)
	_bm_lf_expect_options(lf-os "${_win}" TRUE)
	_bm_lf_expect_options(lf-os "${_linux}" FALSE)
	_bm_lf_expect_options(lf-os "${_mac}" FALSE)
	_bm_lf_expect_options(lf-os "${_unix}" FALSE)
	_bm_lf_expect_options(lf-unix "${_unix}" FALSE)
	_bm_lf_expect_options(lf-unix "${_win}" FALSE)
elseif(APPLE)
	_bm_lf_expect_options(lf-os "${_win}" FALSE)
	_bm_lf_expect_options(lf-os "${_linux}" FALSE)
	_bm_lf_expect_options(lf-os "${_mac}" TRUE)
	_bm_lf_expect_options(lf-os "${_unix}" FALSE)
	_bm_lf_expect_options(lf-unix "${_unix}" TRUE)
	_bm_lf_expect_options(lf-unix "${_mac}" FALSE)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
	_bm_lf_expect_options(lf-os "${_win}" FALSE)
	_bm_lf_expect_options(lf-os "${_linux}" TRUE)
	_bm_lf_expect_options(lf-os "${_mac}" FALSE)
	_bm_lf_expect_options(lf-os "${_unix}" FALSE)
	_bm_lf_expect_options(lf-unix "${_unix}" TRUE)
	_bm_lf_expect_options(lf-unix "${_linux}" FALSE)
else()
	_bm_log_message(CORE FATAL
		"LINKFLAGS check: unhandled CMAKE_SYSTEM_NAME '${CMAKE_SYSTEM_NAME}'")
endif()

_bm_log_message(CORE STATUS "LINKFLAGS groups: OK (${CMAKE_SYSTEM_NAME})")
