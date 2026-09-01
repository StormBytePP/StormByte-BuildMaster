# =============================================================================
# component/install_rules/write.cmake — emit per-id install rules
# =============================================================================

## @brief Configure one oficio template into the scripts tree.
## @param[in]  id      Component id (file stem).
## @param[in]  chan    Log channel baked into the oficio (`CMAKE` / `MESON`).
## @param[in]  title   Human title for FATAL lines.
## @param[in]  safe    Marker-safe id.
## @param[in]  outs    Semicolon list of contract output paths.
## @param[in]  oficio  `rename_library`, `rename_executable`, `outputs`,
##                     `strip_res`, or `pc`.
## @param[out] out_var Parent-scope path of the generated oficio file.
## @note Template: `component/install_rules/templates/<oficio>.cmake.in`.
##       Output: `${BUILDMASTER_SCRIPTSDIR}/install_rules/<id>_<oficio>.cmake`.
## @note Substitutes channel/title/safe/outs, prefix dirs, `CMAKE_AR`,
##       and GLOBAL PC fields. The template itself has no
##       `if(@_BM_*_ENABLED@)` feature flags. Data checks (`EXISTS`,
##       `.lib` suffix, headers-stamp name) stay in the oficio.
## @note `rename_library` worker:
##       `component/rename/normalize_install_libraries.cmake`.
##       `rename_executable` worker:
##       `component/rename/normalize_install_executables.cmake`.
##       The oficio is emitted only if the list contains it.
function(_bm_install_rule_write_one id chan title safe outs oficio out_var)
	_bm_log_message(COMPONENT LOWLEVEL
		"Entering _bm_install_rule_write_one (${id}/${oficio})")
	set(_in
		"${BUILDMASTER_SRCDIR}/component/install_rules/templates/${oficio}.cmake.in")
	if(NOT EXISTS "${_in}")
		_bm_log_message(COMPONENT FATAL
			"_bm_install_rule_write_one: missing template '${_in}'")
	endif()
	set(_dir "${BUILDMASTER_SCRIPTSDIR}/install_rules")
	file(MAKE_DIRECTORY "${_dir}")
	set(_out "${_dir}/${id}_${oficio}.cmake")

	set(_BM_LOG_CHANNEL "${chan}")
	set(_BM_COMPONENT_TITLE "${title}")
	set(_BM_COMPONENT_SAFE "${safe}")
	set(_BM_OUTPUTS "${outs}")
	get_property(_BM_PC_NAME GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_PC_NAME)
	get_property(_BM_PC_VERSION GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_PC_VERSION)
	get_property(_BM_PC_DESCRIPTION GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_PC_DESCRIPTION)
	get_property(_BM_PC_LIBS GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_PC_LIBS)
	get_property(_BM_PC_REQUIRES GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_PC_REQUIRES)
	get_property(_BM_PC_CFLAGS GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_PC_CFLAGS)
	get_property(_BM_PC_OUT GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_PC_OUT)
	if(NOT DEFINED CMAKE_AR)
		set(CMAKE_AR "")
	endif()

	configure_file("${_in}" "${_out}" @ONLY)
	set(${out_var} "${_out}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_install_rule_write_one")
endfunction()

## @brief Build the active oficio list for one id.
## @param[in]  id      Component id.
## @param[out] out_var Parent-scope list of oficio names, in run order.
## @note If create already sealed
##       `BUILDMASTER_COMPONENT_<id>_INSTALL_OFICIOS` and it is not
##       empty, that list wins.
## @note Otherwise derives from sealed properties:
##       - `headers` → `outputs` only (stamp may be created; never
##         rename/strip a `.bm_*_headers.stamp`).
##       - RENAME (GLOBAL `…_RENAME`; unset means ON) →
##         `rename_library` or `rename_executable` according to mode.
##       - every non-empty selection includes `outputs`.
##       - `static` + STRIPRES (GLOBAL `…_STRIPRES`; unset means ON) →
##         `strip_res`.
##       - library (not `executable`) + `BUILDMASTER_COMPONENT_<id>_PC`
##         → `pc`.
## @note Order is rename → outputs → strip_res → pc.
function(_bm_install_rules_select id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_install_rules_select")
	get_property(_listed GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_INSTALL_OFICIOS)
	if(NOT "${_listed}" STREQUAL "")
		set(${out_var} "${_listed}" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_install_rules_select")
		return()
	endif()

	get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_MODE)
	string(TOLOWER "${_mode}" _mode)
	set(_list "")

	if(_mode STREQUAL "headers")
		list(APPEND _list "outputs")
		set(${out_var} "${_list}" PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_install_rules_select")
		return()
	endif()

	get_property(_rename_set GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_RENAME SET)
	get_property(_rename GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${id}_RENAME)
	if(NOT _rename_set)
		set(_rename TRUE)
	endif()
	if(_rename)
		if(_mode STREQUAL "executable")
			list(APPEND _list "rename_executable")
		else()
			list(APPEND _list "rename_library")
		endif()
	endif()

	list(APPEND _list "outputs")

	if(_mode STREQUAL "static")
		get_property(_strip_set GLOBAL PROPERTY
			BUILDMASTER_COMPONENT_${id}_STRIPRES SET)
		get_property(_strip GLOBAL PROPERTY
			BUILDMASTER_COMPONENT_${id}_STRIPRES)
		if(NOT _strip_set)
			set(_strip TRUE)
		endif()
		if(_strip)
			list(APPEND _list "strip_res")
		endif()
	endif()

	if(NOT _mode STREQUAL "executable")
		get_property(_pc GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_PC)
		if(_pc)
			list(APPEND _list "pc")
		endif()
	endif()

	set(${out_var} "${_list}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_install_rules_select")
endfunction()

## @brief Write `${id}_install_rules.cmake`: includes of active oficios only.
## @param[in]  id      Component id.
## @param[in]  chan    `CMAKE` or `MESON` (log channel inside oficios).
## @param[in]  title   Human title.
## @param[in]  safe    Marker-safe id.
## @param[in]  outs    Contract output paths (semicolon list).
## @param[out] out_var Parent-scope path of the rules file.
## @note The generated file is only `include("…")` lines. Selection
##       happens here. FATAL if no oficio is selected or if the file
##       cannot be written.
## @note Calls `_bm_component_pkgconfig_fill_vars` before configuring
##       `pc` so GLOBAL `BUILDMASTER_COMPONENT_<id>_PC_*` are sealed
##       for `configure_file`. Do not configure `pc` with empty
##       `PC_NAME` / `PC_VERSION`.
## @note Output path:
##       `${BUILDMASTER_SCRIPTSDIR}/install_rules/${id}_install_rules.cmake`.
## @note `_BM_BUILDONLY` is not decided here. The wrapper substitutes
##       it into oficios that check the NOINSTALL contract (`outputs`).
function(_bm_install_rules_write id chan title safe outs out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_install_rules_write")
	if("${id}" STREQUAL "" OR "${chan}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_install_rules_write: id and chan are required")
	endif()

	_bm_install_rules_select("${id}" _oficios)
	if("${_oficios}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_install_rules_write('${id}'): no install oficios selected")
	endif()

	list(FIND _oficios "pc" _pc_idx)
	if(NOT _pc_idx EQUAL -1)
		_bm_component_pkgconfig_fill_vars("${id}")
	endif()

	set(_includes "")
	foreach(_of IN LISTS _oficios)
		if(_of STREQUAL "")
			continue()
		endif()
		_bm_install_rule_write_one("${id}" "${chan}" "${title}" "${safe}"
			"${outs}" "${_of}" _one)
		string(APPEND _includes "include(\"${_one}\")\n")
	endforeach()

	set(_dir "${BUILDMASTER_SCRIPTSDIR}/install_rules")
	file(MAKE_DIRECTORY "${_dir}")
	set(_rules "${_dir}/${id}_install_rules.cmake")
	file(WRITE "${_rules}" "${_includes}")
	if(NOT EXISTS "${_rules}")
		_bm_log_message(COMPONENT FATAL
			"_bm_install_rules_write('${id}'): failed to write ${_rules}")
	endif()
	set(${out_var} "${_rules}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_install_rules_write")
endfunction()
