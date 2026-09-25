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

## @brief Dest ids recorded in `links/<id>.cmake`, if that file exists.
## @param[in]  _id      Raw component id.
## @param[out] _out_var Parent-scope list. Empty when the file is absent.
## @note `file(READ)` and a quoted MATCHES. `file(STRINGS)` or an
##       unquoted MATCHES splits on `;` and keeps only the first dest.
## @note Do not `include()` the file. The template `unset()`s
##       `_bm_links_dests` after it wires INTERFACE edges.
function(_bm_links_file_dests _id _out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_file_dests")
	set(_out "")
	if(NOT "${_id}" STREQUAL "" AND NOT "${BUILDMASTER_LINKS_DIR}" STREQUAL "")
		_bm_path_sanitize(_safe "${_id}")
		set(_file "${BUILDMASTER_LINKS_DIR}/${_safe}.cmake")
		if(EXISTS "${_file}")
			file(READ "${_file}" _txt)
			if("${_txt}" MATCHES "set\\(_bm_links_dests \"([^\"]*)\"\\)")
				set(_out "${CMAKE_MATCH_1}")
			endif()
		endif()
	endif()
	set(${_out_var} "${_out}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_file_dests")
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
## @note Do not replace dests with this process's `buildmaster_link`
##       edges alone. Nested configure hangs String → Base on
##       `LINKS_ATTACHED` and in the child file. A parent rewrite that
##       drops those dests leaves a skipped consumer with `-lString`
##       and no Base (Darwin two-level namespace, Windows).
## @note Closure is a fixpoint over this process's `buildmaster_link`
##       edges, dest files and `LINKS_ATTACHED`, with a seen-set so a
##       cycle is not followed. Two write passes still exist so a dest
##       file created earlier in this process is visible; they are not
##       a depth limit.
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

	# Union, do not replace. This process often has no String → Base
	# edge; the nested configure recorded it. Dropping it is the
	# `-lString` with no Base failure.
	get_property(_attached GLOBAL PROPERTY
		BUILDMASTER_COMPONENT_${_id}_LINKS_ATTACHED)
	set(_pending "${BM_LINKS_DESTS}")
	# Unquoted list(APPEND) of an empty value is `list(APPEND _pending)`
	# and CMake rejects it. Most ids have no LINKS_ATTACHED.
	if(_attached)
		list(APPEND _pending ${_attached})
	endif()
	_bm_links_file_dests("${_id}" _from_file)
	if(_from_file)
		list(APPEND _pending ${_from_file})
	endif()
	set(_expanded "")
	set(_guard 0)
	while(_pending)
		list(GET _pending 0 _dst)
		list(REMOVE_AT _pending 0)
		if("${_dst}" STREQUAL "" OR "${_dst}" STREQUAL "${_id}")
			continue()
		endif()
		list(FIND _expanded "${_dst}" _seen)
		if(NOT _seen EQUAL -1)
			continue()
		endif()
		list(APPEND _expanded "${_dst}")
		list(FIND BM_LINKS_DESTS "${_dst}" _hit)
		if(_hit EQUAL -1)
			list(APPEND BM_LINKS_DESTS "${_dst}")
		endif()
		math(EXPR _guard "${_guard} + 1")
		if(_guard GREATER 256)
			_bm_log_message(COMPONENT FATAL
				"_bm_links_write_one(${_id}): link closure did not converge")
		endif()
		_bm_links_file_dests("${_dst}" _more)
		foreach(_extra IN LISTS _more)
			list(APPEND _pending "${_extra}")
		endforeach()
		get_property(_more_att GLOBAL PROPERTY
			BUILDMASTER_COMPONENT_${_dst}_LINKS_ATTACHED)
		foreach(_extra IN LISTS _more_att)
			list(APPEND _pending "${_extra}")
		endforeach()
		# Same-process edges are not in the dest file until that id is
		# written. Walking them here is what makes one pass a fixpoint;
		# the second pass only republishes files created earlier.
		_bm_links_closure("${_dst}" _more_edges)
		foreach(_extra IN LISTS _more_edges)
			list(APPEND _pending "${_extra}")
		endforeach()
	endwhile()

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
## @note Two passes so a dest file created earlier in this process is
##       visible to the next id. Depth is the fixpoint in
##       `_bm_links_write_one`, not the pass count. Does **not** merge
##       dest stems into LIBNAMES.
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
## @note Other-process skip does not mean the caller has no dependency.
##       The id is appended to `${CMAKE_BINARY_DIR}/bm-reuse-needs.txt`
##       (the first call in this process truncates that file). The parent
##       component that owns this binary dir applies the need after the
##       nested configure returns: the id plus dests already stored in
##       its links file, and a wait on `<id>_install` or on the component
##       that created the file.
## @note A leftover `links/<id>.cmake` from a previous configure without
##       wipe skips the nested cmake. Then Logger/Base files are never
##       rewritten this run and flatten sees an empty glob. Wipe harness
##       when debugging this path.
function(_bm_links_try_reuse _id _title out_skip)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_try_reuse")
	_bm_links_reuse_needs_reset()
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
			_bm_links_reuse_needs_note("${_id}")
			set(_skip TRUE)
		endif()
	endif()
	set(${out_skip} "${_skip}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_try_reuse")
endfunction()

## @brief Truncate this process's reuse-needs list once per configure.
## @note `${CMAKE_BINARY_DIR}/bm-reuse-needs.txt`. Nested cmake's binary
##       dir is the parent component's build dir. A reconfigure must not
##       keep ids from the previous run.
function(_bm_links_reuse_needs_reset)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_reuse_needs_reset")
	get_property(_done GLOBAL PROPERTY BUILDMASTER_REUSE_NEEDS_RESET)
	if(_done)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_reuse_needs_reset")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_REUSE_NEEDS_RESET TRUE)
	if(NOT "${CMAKE_BINARY_DIR}" STREQUAL "")
		file(WRITE "${CMAKE_BINARY_DIR}/bm-reuse-needs.txt" "")
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_reuse_needs_reset")
endfunction()

## @brief Remember an id whose configure was skipped in another process.
## @param[in] _id Component id that already has `links/<id>.cmake`.
## @note Append-only. The parent reads the file after this cmake returns.
function(_bm_links_reuse_needs_note _id)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_reuse_needs_note")
	if("${_id}" STREQUAL "" OR "${CMAKE_BINARY_DIR}" STREQUAL "")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_reuse_needs_note")
		return()
	endif()
	file(APPEND "${CMAKE_BINARY_DIR}/bm-reuse-needs.txt" "${_id}\n")
	_bm_log_message(COMPONENT DEBUG
		"reuse need ${_id} (configure skipped, still required)")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_reuse_needs_note")
endfunction()

## @brief `_id` plus dest ids already stored in links files, to a fixpoint.
## @param[in]  _id      Raw component id.
## @param[out] _out_var Parent-scope list. Contains `_id` when it is non-empty.
## @note `_bm_links_file_dests` only. Does not re-enter the skipped cmake.
##       A seen-set cuts cycles.
function(_bm_links_reuse_closure _id _out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_reuse_closure")
	set(_expanded "")
	if(NOT "${_id}" STREQUAL "")
		set(_pending "${_id}")
		set(_guard 0)
		while(_pending)
			list(GET _pending 0 _cur)
			list(REMOVE_AT _pending 0)
			if("${_cur}" STREQUAL "")
				continue()
			endif()
			list(FIND _expanded "${_cur}" _seen)
			if(NOT _seen EQUAL -1)
				continue()
			endif()
			list(APPEND _expanded "${_cur}")
			math(EXPR _guard "${_guard} + 1")
			if(_guard GREATER 256)
				_bm_log_message(COMPONENT FATAL
					"_bm_links_reuse_closure(${_id}): link closure did not converge")
			endif()
			_bm_links_file_dests("${_cur}" _more)
			foreach(_extra IN LISTS _more)
				list(APPEND _pending "${_extra}")
			endforeach()
		endwhile()
	endif()
	set(${_out_var} "${_expanded}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_reuse_closure")
endfunction()

## @brief Stage in this process that publishes a skipped id.
## @param[in]  _id       Skipped component id.
## @param[in]  _consumer Component whose nested configure skipped `_id`.
## @param[out] _out_var  Target name, or empty when none can be named.
## @note `<id>_install` when this process has that stage (hoist).
##       NOINSTALL uses `<id>_build`. Otherwise the parent component that
##       created `links/<id>.cmake` (`BUILDMASTER_LINKS_OWNER_<id>`),
##       its `_install`, else its `_build`. Never a self-edge. Not FATAL:
##       a leftover links file has no owner here.
function(_bm_links_reuse_wait_target _id _consumer _out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_reuse_wait_target")
	set(_wait "")
	if(TARGET "${_id}_install")
		set(_wait "${_id}_install")
	else()
		_bm_graph_is_registered("${_id}" _reg)
		if(_reg)
			_bm_graph_is_noinstall("${_id}" _ni)
			if(_ni AND TARGET "${_id}_build")
				set(_wait "${_id}_build")
			endif()
		endif()
	endif()
	if("${_wait}" STREQUAL "")
		get_property(_owner GLOBAL PROPERTY BUILDMASTER_LINKS_OWNER_${_id})
		if(NOT "${_owner}" STREQUAL "" AND NOT "${_owner}" STREQUAL "${_consumer}")
			if(TARGET "${_owner}_install")
				set(_wait "${_owner}_install")
			elseif(TARGET "${_owner}_build")
				set(_wait "${_owner}_build")
			endif()
		endif()
	endif()
	if(_wait STREQUAL "${_consumer}"
			OR _wait STREQUAL "${_consumer}_configure"
			OR _wait STREQUAL "${_consumer}_build"
			OR _wait STREQUAL "${_consumer}_install")
		set(_wait "")
	endif()
	set(${_out_var} "${_wait}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_reuse_wait_target")
endfunction()

## @brief Keep the need a skipped configure would have dropped.
## @param[in] _consumer Component whose build dir may hold
##            `bm-reuse-needs.txt`.
## @note Does not configure or build the skipped id again. Walks each
##       noted id and the dests already in `links/<id>.cmake`. Hangs
##       that closure on `_consumer` (`LINKS_ATTACHED` and an order-only
##       dep) and makes `<consumer>_configure` / `<consumer>_build` wait
##       on the stage from `_bm_links_reuse_wait_target`. Called after
##       the fragment exists, so `add_dependencies` still reaches ninja.
function(_bm_links_apply_reuse_needs _consumer)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_links_apply_reuse_needs")
	if("${_consumer}" STREQUAL "")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_apply_reuse_needs")
		return()
	endif()
	get_property(_bd GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_consumer}_BUILDDIR)
	if("${_bd}" STREQUAL "")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_apply_reuse_needs")
		return()
	endif()
	set(_file "${_bd}/bm-reuse-needs.txt")
	if(NOT EXISTS "${_file}")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_apply_reuse_needs")
		return()
	endif()
	file(STRINGS "${_file}" _lines)
	set(_needs "")
	foreach(_line IN LISTS _lines)
		string(STRIP "${_line}" _line)
		if("${_line}" STREQUAL "")
			continue()
		endif()
		_bm_links_reuse_closure("${_line}" _part)
		foreach(_one IN LISTS _part)
			list(FIND _needs "${_one}" _hit)
			if(_hit EQUAL -1)
				list(APPEND _needs "${_one}")
			endif()
		endforeach()
	endforeach()
	set(_waits "")
	foreach(_need IN LISTS _needs)
		if("${_need}" STREQUAL "" OR "${_need}" STREQUAL "${_consumer}")
			continue()
		endif()
		get_property(_att GLOBAL PROPERTY
			BUILDMASTER_COMPONENT_${_consumer}_LINKS_ATTACHED)
		list(FIND _att "${_need}" _hit)
		if(_hit EQUAL -1)
			set_property(GLOBAL APPEND PROPERTY
				BUILDMASTER_COMPONENT_${_consumer}_LINKS_ATTACHED "${_need}")
		endif()
		if(COMMAND _bm_graph_record_dep)
			_bm_graph_record_dep("${_consumer}" "${_need}")
		endif()
		if(TARGET "${_consumer}" AND TARGET "${_need}")
			target_link_libraries("${_consumer}" INTERFACE "${_need}")
		endif()
		_bm_links_reuse_wait_target("${_need}" "${_consumer}" _wait)
		if(NOT "${_wait}" STREQUAL "")
			list(APPEND _waits "${_wait}")
		endif()
	endforeach()
	if(_waits)
		list(REMOVE_DUPLICATES _waits)
	endif()
	foreach(_w IN LISTS _waits)
		if(TARGET "${_consumer}_configure")
			add_dependencies("${_consumer}_configure" "${_w}")
		endif()
		if(TARGET "${_consumer}_build")
			add_dependencies("${_consumer}_build" "${_w}")
		endif()
		_bm_log_message(COMPONENT DEBUG
			"reuse wait ${_consumer} → ${_w}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_links_apply_reuse_needs")
endfunction()

## @brief Record ids from `links/*.cmake` created during one nested materialize.
## @param[in] _id     Local component that just finished nested configure.
## @param[in] _before CMake list of `links/*.cmake` paths that existed
##            before that nested configure.
## @note Appends each new id to `BUILDMASTER_COMPONENT_<id>_LINKS_ATTACHED`
##       so flatten can walk Logger/Base when the parent only named Buffer.
## @note The first parent component that creates `links/<nested>.cmake`
##       is `BUILDMASTER_LINKS_OWNER_<nested>`. A later process that
##       skips that id waits on this owner's `_install`.
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
		get_property(_bm_owner GLOBAL PROPERTY BUILDMASTER_LINKS_OWNER_${_BM_LINKS_ID})
		if("${_bm_owner}" STREQUAL "")
			set_property(GLOBAL PROPERTY
				BUILDMASTER_LINKS_OWNER_${_BM_LINKS_ID} "${_id}")
		endif()
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
