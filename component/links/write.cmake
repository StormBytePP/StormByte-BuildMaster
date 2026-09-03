# =============================================================================
# component/links/write.cmake — emit ${BUILDMASTER_LINKS_DIR}/<id>.cmake
# =============================================================================

## @brief LINK dests of `_id` that belong in `links/<id>.cmake`.
## @param[in] _id Component id.
## @param[out] _out_var List of dest ids.
## @note Keep the dest even if it is not registered here. Nested
##       Logger/Base only exist as `links/<dest>.cmake`. Skipping
##       unregistered dests emptied Buffer dests and dropped Base
##       from the host SHARED line (`--no-allow-shlib-undefined`).
## @note Ids are raw component ids, never ALIAS. Resolving
##       SharedBuffer → Shared::Buffer before comparing LINK_SOURCES
##       made the walk miss the edge.
function(_bm_links_closure _id _out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_closure")
	set(_out "")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
	set(_i 0)
	foreach(_s IN LISTS _srcs)
		list(GET _dsts ${_i} _d)
		math(EXPR _i "${_i} + 1")
		if(NOT _s STREQUAL "${_id}")
			continue()
		endif()
		if(_d STREQUAL "" OR _d STREQUAL "${_id}")
			continue()
		endif()
		list(APPEND _out "${_d}")
	endforeach()
	list(REMOVE_DUPLICATES _out)
	set(${_out_var} "${_out}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_closure")
endfunction()

## @brief Write one links file for `_id` after that id has materialized.
## @param[in] _id Component or meta id (winner of the first registration).
## @note Filename is `_bm_path_sanitize(_id)`. `@BM_LINKS_ID@` is the raw id.
## @note `BM_LINKS_LIBNAMES` is **this** id's produced stems only.
##       Dest stems belong in `BM_LINKS_DESTS`. Merging dest names into
##       LIBNAMES made the template emit `INTERFACE leaflib` and the
##       parent line grew `-lleaflib` (not in `-L` of a prefix subdir).
## @note Read dest files with `file(READ)` + quoted `if("${_dtxt}" MATCHES)`.
##       `file(STRINGS)` and unquoted MATCHES split on `;` and drop Base
##       from `LIBNAMES "Logger;Base"`.
## @note Do not `include()` dest files here: the template `unset()`s dests.
## @note `mode=executable` writes an empty LIBNAMES. An exe is never a
##       link input, including when the id sits in a meta. Order-only
##       edges still flow through DESTS / *_install.
function(_bm_links_write_one _id)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_write_one")
	if("${_id}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "_bm_links_write_one: empty id")
	endif()
	if("${BUILDMASTER_LINKS_DIR}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_links_write_one: BUILDMASTER_LINKS_DIR is empty")
	endif()
	file(MAKE_DIRECTORY "${BUILDMASTER_LINKS_DIR}")

	_bm_graph_is_registered("${_id}" _is_c)
	_bm_meta_is("${_id}" _is_m)
	set(BM_LINKS_LIBDIR "")
	set(BM_LINKS_LIBNAMES "")
	set(_ni FALSE)
	set(_priv FALSE)
	set(_bd "")
	set(_mode "")
	if(_is_c)
		get_property(BM_LINKS_TITLE GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_TITLE)
		get_property(_ni GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_NOINSTALL)
		get_property(_priv GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_PRIVATE_HEADERS)
		get_property(_prod GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_PRODUCED)
		get_property(_bd GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_BUILDDIR)
		get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_MODE)
		if(_ni)
			set(BM_LINKS_LIBDIR "")
		else()
			set(BM_LINKS_LIBDIR "${BUILDMASTER_INSTALL_LIBDIR}")
		endif()
		# Exe stems must not reach IMPORTED NAMES / flatten (-lgzip / gzip.exe).
		if(NOT _mode STREQUAL "executable")
			foreach(_spec IN LISTS _prod)
				if(_spec STREQUAL "")
					continue()
				endif()
				_bm_opt_parse_spec("${_spec}" _ign_tgt _bn _ign_dir)
				if(NOT _bn STREQUAL "")
					list(APPEND BM_LINKS_LIBNAMES "${_bn}")
				endif()
			endforeach()
		else()
			set(BM_LINKS_LIBDIR "")
		endif()
	elseif(_is_m)
		get_property(BM_LINKS_TITLE GLOBAL PROPERTY BUILDMASTER_META_${_id}_TITLE)
		get_property(_ni GLOBAL PROPERTY BUILDMASTER_META_${_id}_NOINSTALL)
		set(_bd "")
	else()
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_write_one")
		return()
	endif()
	if("${BM_LINKS_TITLE}" STREQUAL "")
		set(BM_LINKS_TITLE "${_id}")
	endif()

	set(BM_LINKS_ID "${_id}")
	get_property(BM_LINKS_ALIASES GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_ALIASES)
	_bm_links_closure("${_id}" BM_LINKS_DESTS)

	foreach(_dst IN LISTS BM_LINKS_DESTS)
		if(_dst STREQUAL "")
			continue()
		endif()
		_bm_path_sanitize(_safe_dst "${_dst}")
		set(_dfile "${BUILDMASTER_LINKS_DIR}/${_safe_dst}.cmake")
		if(NOT EXISTS "${_dfile}")
			continue()
		endif()
		file(READ "${_dfile}" _dtxt)
		if("${_dtxt}" MATCHES "set\\(_bm_links_dests \"([^\"]*)\"\\)")
			foreach(_extra IN LISTS CMAKE_MATCH_1)
				if(_extra STREQUAL "" OR _extra STREQUAL "${_id}")
					continue()
				endif()
				list(FIND BM_LINKS_DESTS "${_extra}" _hit)
				if(_hit EQUAL -1)
					list(APPEND BM_LINKS_DESTS "${_extra}")
				endif()
			endforeach()
		endif()
	endforeach()

	set(BM_LINKS_INCLUDES "")
	if(_priv)
		# Private headers: consumer OPTIONS get -I<srcdir>. Never INTERFACE.
	elseif(_ni AND NOT "${_bd}" STREQUAL "")
		set(BM_LINKS_INCLUDES "${_bd}")
	elseif(NOT _ni AND NOT "${BUILDMASTER_INSTALL_INCLUDEDIR}" STREQUAL "")
		set(BM_LINKS_INCLUDES "${BUILDMASTER_INSTALL_INCLUDEDIR}")
	endif()

	_bm_path_sanitize(_safe "${_id}")
	set(_out "${BUILDMASTER_LINKS_DIR}/${_safe}.cmake")
	configure_file(
		"${BUILDMASTER_COMPONENT_SRCDIR}/links/templates/link.cmake.in"
		"${_out}"
		@ONLY
	)
	_bm_log_message(COMPONENT DEBUG
		"Wrote links ${_id} names=${BM_LINKS_LIBNAMES} dests=${BM_LINKS_DESTS} → ${_out}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_write_one")
endfunction()

## @brief Write links files for every component and created meta in this process.
## @note Two passes: first creates the files (so a dest living only as
##       `links/<dest>.cmake` is visible); second rewrites dests after
##       those files exist. Does **not** merge dest stems into LIBNAMES.
function(_bm_links_write_all)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_write_all")
	set(_all "")
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	list(APPEND _all ${_ids})
	get_property(_metas GLOBAL PROPERTY BUILDMASTER_META_IDS)
	foreach(_id IN LISTS _metas)
		get_property(_created GLOBAL PROPERTY BUILDMASTER_META_${_id}_CREATED)
		if(_created)
			list(APPEND _all "${_id}")
		endif()
	endforeach()
	foreach(_pass RANGE 1 2)
		foreach(_id IN LISTS _all)
			_bm_links_write_one("${_id}")
		endforeach()
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_write_all")
endfunction()

## @brief Include `${BUILDMASTER_LINKS_DIR}/*.cmake` (IMPORTED stubs + aliases).
## @note Runs after nested materialize so the child already wrote the file.
##       Missing file is not FATAL here: `shlwapi` / specs still resolve in
##       `_bm_materialize_apply_links`.
## @note `include()` of a links file `unset()`s `_bm_links_dests`. After
##       ingest, flatten must `file(READ)` — never re-include — to walk dests.
function(_bm_links_ingest_needed)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_ingest_needed")
	if("${BUILDMASTER_LINKS_DIR}" STREQUAL "")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_ingest_needed")
		return()
	endif()
	file(GLOB _bm_link_files "${BUILDMASTER_LINKS_DIR}/*.cmake")
	if(NOT _bm_link_files)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_ingest_needed")
		return()
	endif()
	foreach(_bm_pass RANGE 1 2)
		foreach(_file IN LISTS _bm_link_files)
			include("${_file}")
		endforeach()
	endforeach()
	_bm_log_message(COMPONENT DEBUG
		"Ingested links files (${_bm_link_files})")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_ingest_needed")
endfunction()

## @brief Whether `_id` must not be registered again in this process.
## @param[in]  _id     Component id being declared.
## @param[in]  _title  Title of this call (log only).
## @param[out] out_skip Parent-scope TRUE if the caller must return.
## @note Same-process: id already in COMPONENT_IDS or a created meta.
##       Other process: `${BUILDMASTER_LINKS_DIR}/<sanitized>.cmake` exists
##       → include it (IMPORTED stub + aliases) and treat as already built.
## @note A leftover `links/<id>.cmake` from a previous configure without
##       wipe skips the nested cmake. Then Logger/Base files are never
##       rewritten this run and flatten sees an empty glob. Wipe harness
##       when debugging this path.
function(_bm_links_try_reuse _id _title out_skip)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_try_reuse")
	set(_skip FALSE)
	if("${_id}" STREQUAL "")
		set(${out_skip} FALSE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_try_reuse")
		return()
	endif()
	_bm_graph_is_registered("${_id}" _is_c)
	if(_is_c)
		get_property(_who GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_TITLE)
		if("${_who}" STREQUAL "")
			set(_who "${_id}")
		endif()
		_bm_log_message(COMPONENT STATUS
			"Skipping configure of ${_title} — already registered as '${_who}' (${_id})")
		set(_skip TRUE)
	endif()
	if(NOT _skip)
		_bm_meta_is("${_id}" _is_m)
		if(_is_m)
			get_property(_created GLOBAL PROPERTY BUILDMASTER_META_${_id}_CREATED)
			if(_created)
				get_property(_who GLOBAL PROPERTY BUILDMASTER_META_${_id}_TITLE)
				if("${_who}" STREQUAL "")
					set(_who "${_id}")
				endif()
				_bm_log_message(COMPONENT STATUS
					"Skipping configure of ${_title} — already registered as '${_who}' (${_id})")
				set(_skip TRUE)
			endif()
		endif()
	endif()
	if(NOT _skip AND NOT "${BUILDMASTER_LINKS_DIR}" STREQUAL "")
		_bm_path_sanitize(_safe "${_id}")
		set(_file "${BUILDMASTER_LINKS_DIR}/${_safe}.cmake")
		if(EXISTS "${_file}")
			include("${_file}")
			set(_who "${_id}")
			if(DEFINED _BM_LINKS_ORIGIN_TITLE AND NOT "${_BM_LINKS_ORIGIN_TITLE}" STREQUAL "")
				set(_who "${_BM_LINKS_ORIGIN_TITLE}")
			endif()
			_bm_log_message(COMPONENT STATUS
				"Skipping configure of ${_title} — already built by '${_who}' (${_id})")
			set(_skip TRUE)
		endif()
	endif()
	set(${out_skip} "${_skip}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_try_reuse")
endfunction()

## @brief Record ids from `links/*.cmake` created during one nested materialize.
## @param[in] _id     Local component that just finished nested configure.
## @param[in] _before CMake list of `links/*.cmake` paths that existed
##            before that nested configure.
## @note Appends each new id to `BUILDMASTER_COMPONENT_<id>_LINKS_ATTACHED`
##       so flatten can walk Logger/Base when the parent only named Buffer.
## @note Does **not** `target_link_libraries(INTERFACE <stem>)`.
##       Raw stems become `-lmidlib` on a parent that already has the
##       NAMES path under a prefix subdir.
function(_bm_links_attach_new _id _before)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_attach_new")
	if("${_id}" STREQUAL "" OR NOT TARGET "${_id}")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_attach_new")
		return()
	endif()
	if("${BUILDMASTER_LINKS_DIR}" STREQUAL "")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_attach_new")
		return()
	endif()
	file(GLOB _after "${BUILDMASTER_LINKS_DIR}/*.cmake")
	foreach(_file IN LISTS _after)
		list(FIND _before "${_file}" _hit)
		if(NOT _hit EQUAL -1)
			continue()
		endif()
		unset(_BM_LINKS_ID)
		unset(_BM_LINKS_LIBDIR)
		unset(_BM_LINKS_LIBNAMES)
		include("${_file}")
		if(NOT DEFINED _BM_LINKS_ID OR "${_BM_LINKS_ID}" STREQUAL "")
			continue()
		endif()
		if(_BM_LINKS_ID STREQUAL "${_id}")
			continue()
		endif()
		set_property(GLOBAL APPEND PROPERTY
			BUILDMASTER_COMPONENT_${_id}_LINKS_ATTACHED "${_BM_LINKS_ID}")
		if(NOT _BM_LINKS_LIBDIR STREQUAL "")
			target_link_directories("${_id}" INTERFACE "${_BM_LINKS_LIBDIR}")
		endif()
		if(TARGET "${_BM_LINKS_ID}")
			target_link_libraries("${_id}" INTERFACE "${_BM_LINKS_ID}")
		endif()
		if(COMMAND _bm_graph_record_dep)
			_bm_graph_record_dep("${_id}" "${_BM_LINKS_ID}")
		endif()
		_bm_log_message(COMPONENT DEBUG
			"links attach ${_id} → ${_BM_LINKS_ID}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_attach_new")
endfunction()

## @brief Hang unregistered nested dests onto a real host.
## @param[in] _src Host target (STATIC/SHARED). Not a BM INTERFACE stub.
## @param[in] _root Dest id of this buildmaster_link (raw id, not ALIAS).
## @param[in] _vis  PUBLIC.
## @note Reads `links/<id>.cmake` with `file(READ)` + quoted MATCHES.
## @note Do not `include()` the file. Do not alias-resolve LINK/DEP ids.
## @note `-lStem` / `Stem.lib` only if `_cur` is **not** registered here.
## @note Unix: `target_link_libraries(host PUBLIC "-lStem")`.
##       Windows: `target_link_libraries(host PUBLIC "Stem.lib")`.
##       Never `target_link_options(LINKER:-lStem)` (bfd: DSO missing).
##       Never `-l` on `link.exe` (LNK4044 / unresolved).
## @note Do not pass an absolute `.so`/`.lib` (ninja source, no rule).
## @note Do not `target_link_libraries(host PUBLIC <id>)` when `<id>`
##       is the BM INTERFACE stub (no location → empty line).
function(_bm_links_flatten_onto _src _root _vis)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_flatten_onto")
	if("${_src}" STREQUAL "" OR NOT TARGET "${_src}" OR "${_root}" STREQUAL "")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_flatten_onto")
		return()
	endif()
	set(_stack "${_root}")
	set(_seen "${_root}")
	set(_emitted "")
	set(_missing "")
	get_property(_att GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_root}_LINKS_ATTACHED)
	foreach(_a IN LISTS _att)
		if(_a STREQUAL "")
			continue()
		endif()
		list(FIND _seen "${_a}" _hit)
		if(_hit EQUAL -1)
			list(APPEND _seen "${_a}")
			list(APPEND _stack "${_a}")
		endif()
	endforeach()
	while(_stack)
		list(GET _stack 0 _cur)
		list(REMOVE_AT _stack 0)

		set(_libdir "")
		set(_libnames "")
		set(_dests "")
		if(NOT "${BUILDMASTER_LINKS_DIR}" STREQUAL "")
			set(_file "${BUILDMASTER_LINKS_DIR}/${_cur}.cmake")
			if(EXISTS "${_file}")
				file(READ "${_file}" _txt)
				if("${_txt}" MATCHES "set\\(_BM_LINKS_LIBDIR \"([^\"]*)\"\\)")
					set(_libdir "${CMAKE_MATCH_1}")
				endif()
				if("${_txt}" MATCHES "set\\(_BM_LINKS_LIBNAMES \"([^\"]*)\"\\)")
					set(_libnames "${CMAKE_MATCH_1}")
				endif()
				if("${_txt}" MATCHES "set\\(_bm_links_dests \"([^\"]*)\"\\)")
					set(_dests "${CMAKE_MATCH_1}")
				endif()
			else()
				list(APPEND _missing "${_cur}")
			endif()
		endif()

		set(_cur_reg FALSE)
		_bm_graph_is_registered("${_cur}" _cur_reg)
		if(NOT _cur_reg)
			if(NOT _libdir STREQUAL "")
				target_link_directories("${_src}" ${_vis} "${_libdir}")
			endif()
			foreach(_ln IN LISTS _libnames)
				if(_ln STREQUAL "" OR _ln STREQUAL "${_src}")
					continue()
				endif()
				if(WIN32)
					target_link_libraries("${_src}" ${_vis} "${_ln}.lib")
				else()
					target_link_libraries("${_src}" ${_vis} "-l${_ln}")
				endif()
				list(APPEND _emitted "${_ln}")
			endforeach()
		endif()
		foreach(_d IN LISTS _dests)
			if(_d STREQUAL "")
				continue()
			endif()
			list(FIND _seen "${_d}" _hit)
			if(_hit EQUAL -1)
				list(APPEND _seen "${_d}")
				list(APPEND _stack "${_d}")
			endif()
		endforeach()

		get_property(_more GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_cur}_LINKS_ATTACHED)
		foreach(_a IN LISTS _more)
			if(_a STREQUAL "")
				continue()
			endif()
			list(FIND _seen "${_a}" _hit)
			if(_hit EQUAL -1)
				list(APPEND _seen "${_a}")
				list(APPEND _stack "${_a}")
			endif()
		endforeach()

		foreach(_prop LINK DEP)
			get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_prop}_SOURCES)
			get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_prop}_DESTS)
			set(_i 0)
			foreach(_s IN LISTS _srcs)
				list(GET _dsts ${_i} _d)
				math(EXPR _i "${_i} + 1")
				if(NOT _s STREQUAL "${_cur}")
					continue()
				endif()
				list(FIND _seen "${_d}" _hit)
				if(_hit EQUAL -1)
					list(APPEND _seen "${_d}")
					list(APPEND _stack "${_d}")
				endif()
			endforeach()
		endforeach()
	endwhile()
	if(_emitted)
		list(REMOVE_DUPLICATES _emitted)
	endif()
	_bm_log_message(COMPONENT DEBUG
		"flatten ${_src} ← ${_root} seen=${_seen} -l=${_emitted} missing=${_missing}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_flatten_onto")
endfunction()
