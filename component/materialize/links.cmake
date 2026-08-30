# =============================================================================
# component/materialize/links.cmake — PRIVATE -I inject + LINKFLAGS fold + apply_links
# =============================================================================

## @brief Fold one `-I<path>` token into cmake/meson OPTIONS (configure only).
## @param[in] _sys `cmake` or `meson`.
## @param[in,out] _opts_var Name of a CMake list variable holding OPTIONS.
## @param[in] _tok Single token from `_bm_path_compile_include` (`-I<path>`).
## @note CMake: `-DCMAKE_C_FLAGS=…` and `-DCMAKE_CXX_FLAGS=…` (append).
##       Meson: `-Dc_args=…` and `-Dcpp_args=…` (append).
##       Does not write ENV, the native file, or INTERFACE.
##       Several dests → several `-I` in the same `-D` value.
function(_bm_materialize_options_add_include _sys _opts_var _tok)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_options_add_include")
	set(_opts "${${_opts_var}}")
	if(_sys STREQUAL "cmake")
		set(_keys CMAKE_C_FLAGS CMAKE_CXX_FLAGS)
	else()
		set(_keys c_args cpp_args)
	endif()
	foreach(_k IN LISTS _keys)
		set(_found FALSE)
		set(_new "")
		foreach(_o IN LISTS _opts)
			if(_o MATCHES "^-D${_k}=")
				set(_found TRUE)
				string(REGEX REPLACE "^-D${_k}=" "" _val "${_o}")
				if(_val STREQUAL "")
					list(APPEND _new "-D${_k}=${_tok}")
				else()
					list(APPEND _new "-D${_k}=${_val} ${_tok}")
				endif()
			else()
				list(APPEND _new "${_o}")
			endif()
		endforeach()
		if(NOT _found)
			list(APPEND _new "-D${_k}=${_tok}")
		endif()
		set(_opts "${_new}")
	endforeach()
	set(${_opts_var} "${_opts}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_options_add_include")
endfunction()

## @brief Fold one raw linker flag into cmake/meson OPTIONS (configure only).
## @param[in] _sys `cmake` or `meson`.
## @param[in,out] _opts_var Name of a CMake list variable holding OPTIONS.
## @param[in] _tok Single raw flag (`-Wl,-Bsymbolic`, `/FORCE:MULTIPLE`).
## @note CMake: `-DCMAKE_EXE_LINKER_FLAGS=…`, `-DCMAKE_SHARED_LINKER_FLAGS=…`,
##       `-DCMAKE_MODULE_LINKER_FLAGS=…` (append). Not `CMAKE_STATIC_LINKER_FLAGS`
##       (that is the archiver).
##       Meson: `-Dc_link_args=…` and `-Dcpp_link_args=…` (append).
##       Does not write ENV, the native file, or INTERFACE.
##       Several flags → several tokens in the same `-D` value.
function(_bm_materialize_options_add_linkflag _sys _opts_var _tok)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_options_add_linkflag")
	set(_opts "${${_opts_var}}")
	if(_sys STREQUAL "cmake")
		set(_keys CMAKE_EXE_LINKER_FLAGS CMAKE_SHARED_LINKER_FLAGS CMAKE_MODULE_LINKER_FLAGS)
	else()
		set(_keys c_link_args cpp_link_args)
	endif()
	foreach(_k IN LISTS _keys)
		set(_found FALSE)
		set(_new "")
		foreach(_o IN LISTS _opts)
			if(_o MATCHES "^-D${_k}=")
				set(_found TRUE)
				string(REGEX REPLACE "^-D${_k}=" "" _val "${_o}")
				if(_val STREQUAL "")
					list(APPEND _new "-D${_k}=${_tok}")
				else()
					list(APPEND _new "-D${_k}=${_val} ${_tok}")
				endif()
			else()
				list(APPEND _new "${_o}")
			endif()
		endforeach()
		if(NOT _found)
			list(APPEND _new "-D${_k}=${_tok}")
		endif()
		set(_opts "${_new}")
	endforeach()
	set(${_opts_var} "${_opts}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_options_add_linkflag")
endfunction()

## @brief Fold every path in a list onto `_id` OPTIONS via `_bm_path_compile_include`.
## @param[in] _id   Component that receives the flags.
## @param[in] _sys  `cmake` or `meson`.
## @param[in] _dirs Absolute directories.
function(_bm_materialize_add_include_dirs _id _sys _dirs)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_add_include_dirs")
	if(_sys STREQUAL "none" OR _sys STREQUAL "" OR _sys STREQUAL "pending")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_add_include_dirs")
		return()
	endif()
	get_property(_opts GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_OPTIONS)
	foreach(_dir IN LISTS _dirs)
		if("${_dir}" STREQUAL "")
			continue()
		endif()
		if(NOT IS_DIRECTORY "${_dir}")
			_bm_log_message(COMPONENT FATAL
				"'${_id}': include dir '${_dir}' is not a directory")
		endif()
		_bm_path_compile_include(_tok "${_dir}")
		_bm_materialize_options_add_include("${_sys}" _opts "${_tok}")
		_bm_log_message(COMPONENT DEBUG "${_id}: FILES/PRIVATE -I ${_tok}")
	endforeach()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_OPTIONS "${_opts}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_add_include_dirs")
endfunction()

## @brief Inject FILES unpack `-I` onto the owner, then PRIVATE headers
##        `-I<srcdir>` (+ that dest's FILES includes) onto each linker source.
## @note Owner FILES includes are payload of that id (Opus DNN). They do not
##       walk the graph.
## @note PRIVATE headers dest: source gets dest SRCDIR and dest FILES_INCLUDES.
##       Meta dests are skipped. Source `SYSTEM=none` cannot receive flags.
## @note Must run after FILES apply and pending resolve, before nested configure.
function(_bm_materialize_inject_private_headers)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_inject_private_headers")

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		foreach(_id IN LISTS _ids)
			get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM)
			get_property(_finc GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_FILES_INCLUDES)
			if(_finc)
				_bm_materialize_add_include_dirs("${_id}" "${_sys}" "${_finc}")
			endif()
		endforeach()
	endif()

	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
	if(NOT _srcs)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_inject_private_headers")
		return()
	endif()
	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")
		get_property(_priv GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_PRIVATE_HEADERS)
		if(NOT _priv)
			continue()
		endif()
		_bm_meta_is("${_dst}" _dst_meta)
		if(_dst_meta)
			continue()
		endif()
		get_property(_ssys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_src}_SYSTEM)
		if(_ssys STREQUAL "none" OR _ssys STREQUAL "")
			_bm_log_message(COMPONENT NOTICE
				"buildmaster_link('${_src}', '${_dst}'): source has no cmake/meson backend; PRIVATE headers `-I` not applied")
			continue()
		endif()
		get_property(_srcdir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_SRCDIR)
		set(_dirs "${_srcdir}")
		get_property(_finc GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_FILES_INCLUDES)
		if(_finc)
			list(APPEND _dirs ${_finc})
		endif()
		_bm_materialize_add_include_dirs("${_src}" "${_ssys}" "${_dirs}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_inject_private_headers")
endfunction()

## @brief Fold each concrete id's LINKFLAGS into that id's nested OPTIONS.
## @note Walks `BUILDMASTER_COMPONENT_IDS`. Skips `none` / empty / `pending`
##       (pending must already have been resolved). A meta is not in this
##       list; `buildmaster_meta` WARNING + clears before finalize.
## @note Does not write INTERFACE. Does not walk `buildmaster_link` edges:
##       flags belong to the declaring id's nested cmake / meson only.
## @note Must run after FILES / pending resolve and PRIVATE `-I` inject,
##       before backend materialize so stages see the folded `-D`.
function(_bm_materialize_inject_linkflags)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_inject_linkflags")
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(NOT _ids)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_inject_linkflags")
		return()
	endif()
	foreach(_id IN LISTS _ids)
		get_property(_flags GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_LINKFLAGS)
		if(NOT _flags)
			continue()
		endif()
		get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM)
		if(_sys STREQUAL "none" OR _sys STREQUAL "" OR _sys STREQUAL "pending")
			_bm_log_message(COMPONENT NOTICE
				"'${_id}': LINKFLAGS not applied (no cmake/meson backend)")
			continue()
		endif()
		get_property(_opts GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_OPTIONS)
		foreach(_tok IN LISTS _flags)
			if(_tok STREQUAL "")
				continue()
			endif()
			_bm_materialize_options_add_linkflag("${_sys}" _opts "${_tok}")
			_bm_log_message(COMPONENT DEBUG "${_id}: LINKFLAGS ${_tok}")
		endforeach()
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_OPTIONS "${_opts}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_inject_linkflags")
endfunction()

## @brief Apply recorded buildmaster_link edges after all fragments are included.
## @note Walks `BUILDMASTER_COMPONENT_LINK_SOURCES` / `_DESTS` in lockstep.
## @note Dest kinds: meta INTERFACE, registered component (WHOLE vs produced
##       IMPORTED names), existing CMake target, an existing archive file,
##       or a library spec (`<name>` or `<subdir>/<name>`) resolved to the
##       canonical path under `BUILDMASTER_INSTALL_LIBDIR` using the *source*
##       component mode. The file need not exist at configure (install later).
## @note Dest that is none of the above is FATAL. Raw system linker names
##       (`shlwapi`, `ws2_32`) belong in `LINK=` / `LINK={…}` on the producer,
##       not here.
## @note FATAL if source is not a target. FATAL if dest is BUILDONLY and
##       not `PRIVATE_HEADERS`. A `PRIVATE_HEADERS` dest is wait-only here
##       (no INTERFACE link line; `-I` was injected into the source OPTIONS).
function(_bm_materialize_apply_links)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_materialize_apply_links")
	get_property(_lsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
	if(NOT _lsrcs)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_apply_links")
		return()
	endif()
	set(_i 0)
	foreach(_src IN LISTS _lsrcs)
		list(GET _ldsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")

		if(NOT TARGET "${_src}")
			_bm_log_message(COMPONENT FATAL
				"buildmaster_link: source '${_src}' is not a target (missing buildmaster_component?)")
		endif()

		_bm_meta_is("${_dst}" _dst_meta)
		if(_dst_meta)
			if(TARGET "${_dst}")
				target_link_libraries(${_src} INTERFACE ${_dst})
			endif()
			continue()
		endif()

		_bm_graph_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			get_property(_dst_priv GLOBAL PROPERTY
				BUILDMASTER_COMPONENT_${_dst}_PRIVATE_HEADERS)
			if(_dst_priv)
				_bm_log_message(COMPONENT DEBUG
					"buildmaster_link '${_src}' → PRIVATE headers '${_dst}' (no INTERFACE line)")
				continue()
			endif()
			_bm_graph_is_buildonly("${_dst}" _dst_bo)
			if(_dst_bo)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_link: cannot link to BUILDONLY component '${_dst}' (order only via buildmaster_depend between BUILDONLY phases, or publish it with a REPACK meta)")
			endif()
			get_property(_dst_whole GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_WHOLE)
			if(_dst_whole)
				if(TARGET "${_dst}")
					target_link_libraries(${_src} INTERFACE ${_dst})
				endif()
			else()
				get_property(_names GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_NAMES)
				foreach(_lib IN LISTS _names)
					if(TARGET "${_lib}")
						target_link_libraries(${_src} INTERFACE ${_lib})
					endif()
				endforeach()
				if(TARGET "${_dst}")
					target_link_libraries(${_src} INTERFACE ${_dst})
				endif()
			endif()
			continue()
		endif()

		if(TARGET "${_dst}")
			target_link_libraries(${_src} INTERFACE ${_dst})
			continue()
		endif()

		if(EXISTS "${_dst}" AND NOT IS_DIRECTORY "${_dst}")
			target_link_libraries(${_src} INTERFACE "${_dst}")
			continue()
		endif()

		set(_spec_ok FALSE)
		if(_dst MATCHES "/")
			set(_spec_ok TRUE)
		elseif(_dst MATCHES "\\.(a|lib|so|dll|dylib)$")
			set(_spec_ok TRUE)
		endif()
		if(_spec_ok)
			get_property(_src_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_src}_MODE)
			if(_src_mode STREQUAL "" OR _src_mode STREQUAL "headers")
				set(_src_mode "static")
			endif()
			set(_spec_names "")
			set(_spec_files "")
			set(_spec_dlls "")
			_bm_opt_append_spec(
				"${_src_mode}" "${_dst}" "${BUILDMASTER_INSTALL_LIBDIR}"
				_spec_names _spec_files _spec_dlls)
			if(_spec_files)
				target_link_libraries(${_src} INTERFACE ${_spec_files})
				_bm_log_message(COMPONENT DEBUG
					"buildmaster_link '${_src}' → spec '${_dst}' → ${_spec_files}")
				continue()
			endif()
		endif()

		_bm_log_message(COMPONENT FATAL
			"buildmaster_link('${_src}', '${_dst}'): dest is not a BM component, meta, existing CMake target, on-disk archive, or library spec (<name> or <subdir>/<name>). Raw system libraries belong in LINK= / LINK={…}.")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_materialize_apply_links")
endfunction()
