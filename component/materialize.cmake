# =============================================================================
# component/materialize.cmake — fragment emit, links, deferred finalize
# =============================================================================
# Backends call _bm_comp_collect_outputs / write_fragment.
# Finalize is scheduled by _bm_graph_defer_arm (graph.cmake).

## @brief Fill produced names/files/dlls and install/build contract outputs.
## @param[in] _component Registered component id.
## @note Sets parent-scope: `_LIBRARY_COMPONENT_NAMES`, `_LIBRARY_COMPONENT_FILES`,
##       `_LIBRARY_COMPONENT_DLL_FILES`, `_output_libraries`, `_BM_RENAME_ENABLED`,
##       `_BM_BUILDONLY`, `_BM_STRIPRES_ENABLED`, `_BM_PC_*`, `_indent_level`,
##       `_toolchain`.
## @note BUILDONLY uses the component BUILDDIR as the library root; otherwise
##       `BUILDMASTER_INSTALL_LIBDIR`. Headers mode emits a stamp path, not libs.
## @note Extra `buildmaster_link` dests that are library specs (`<name>` or
##       `<subdir>/<name>`, not a component, meta, CMake target, or existing
##       file) are appended to the produced name/file lists so the fragment
##       can create IMPORTED targets. They are *not* added to stage `OUTPUT`:
##       `create_*_stages` already ran at registration with the declared
##       produced specs only. `write_fragment` attaches a Ninja file rule
##       (`OUTPUT <file>` `DEPENDS` `<id>_install`) for each extra. Without
##       that rule Ninja reports “needed by <host>, missing and no known
##       rule”; Unix Makefiles often hide it via target-level dependencies.
## @note `_BM_STRIPRES_ENABLED` is `1` only for static mode when STRIPRES is on
##       (default ON). Shared/headers never strip; install_exec is a no-op there.
## @note `_BM_PC_*` comes from `_bm_pc_fill_vars` (tools/pkgconfig).
##       ENABLED is `1` only when `PC={…}` is on and not BUILDONLY (already FATAL
##       at _bm_comp_create).
function(_bm_comp_collect_outputs _component)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_collect_outputs")
	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRODUCED)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)
	get_property(_builddir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDDIR)

	_bm_opt_parse(
		_indent_level _toolchain _rename_on _buildonly _whole_ignored _stripres_on
		"${_options_string}")

	if(_buildonly)
		set(_BM_BUILDONLY "1")
		set(_base_libdir "${_builddir}")
	else()
		set(_BM_BUILDONLY "0")
		set(_base_libdir "${BUILDMASTER_INSTALL_LIBDIR}")
	endif()

	if(_library_mode STREQUAL "headers")
		set(_BM_RENAME_ENABLED "0")
	elseif(_rename_on)
		set(_BM_RENAME_ENABLED "1")
	else()
		set(_BM_RENAME_ENABLED "0")
	endif()

	if(_library_mode STREQUAL "static" AND _stripres_on)
		set(_BM_STRIPRES_ENABLED "1")
	else()
		set(_BM_STRIPRES_ENABLED "0")
	endif()

	_bm_pc_fill_vars("${_component}")

	set(_LIBRARY_COMPONENT_NAMES "")
	set(_LIBRARY_COMPONENT_FILES "")
	set(_LIBRARY_COMPONENT_DLL_FILES "")
	set(_output_libraries "")

	if(_library_mode STREQUAL "headers")
		if(_buildonly)
			set(_headers_stamp
				"${_builddir}/.bm_${_component}_headers.stamp")
		else()
			set(_headers_stamp
				"${BUILDMASTER_INSTALL_INCLUDEDIR}/.bm_${_component}_headers.stamp")
		endif()
		set(_output_libraries "${_headers_stamp}")
	else()
		foreach(_spec IN LISTS _produced)
			if(_spec STREQUAL "")
				continue()
			endif()
			_bm_opt_append_spec(
				"${_library_mode}" "${_spec}" "${_base_libdir}"
				_LIBRARY_COMPONENT_NAMES _LIBRARY_COMPONENT_FILES
				_LIBRARY_COMPONENT_DLL_FILES)
		endforeach()

		if(NOT _buildonly)
			get_property(_lsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
			get_property(_ldsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
			if(_lsrcs)
				set(_li 0)
				foreach(_lsrc IN LISTS _lsrcs)
					list(GET _ldsts ${_li} _ldst)
					math(EXPR _li "${_li} + 1")
					if(NOT _lsrc STREQUAL "${_component}")
						continue()
					endif()
					_bm_comp_is_registered("${_ldst}" _ldst_comp)
					_bm_meta_is("${_ldst}" _ldst_meta)
					if(_ldst_comp OR _ldst_meta)
						continue()
					endif()
					if(TARGET "${_ldst}")
						continue()
					endif()
					if(EXISTS "${_ldst}" AND NOT IS_DIRECTORY "${_ldst}")
						continue()
					endif()
					_bm_opt_append_spec(
						"${_library_mode}" "${_ldst}" "${_base_libdir}"
						_LIBRARY_COMPONENT_NAMES _LIBRARY_COMPONENT_FILES
						_LIBRARY_COMPONENT_DLL_FILES)
				endforeach()
			endif()
		endif()

		set(_output_libraries "${_LIBRARY_COMPONENT_FILES}")
		if(MSVC AND _library_mode STREQUAL "shared")
			list(APPEND _output_libraries ${_LIBRARY_COMPONENT_DLL_FILES})
		endif()
	endif()

	set(_LIBRARY_COMPONENT_NAMES "${_LIBRARY_COMPONENT_NAMES}" PARENT_SCOPE)
	set(_LIBRARY_COMPONENT_FILES "${_LIBRARY_COMPONENT_FILES}" PARENT_SCOPE)
	set(_LIBRARY_COMPONENT_DLL_FILES "${_LIBRARY_COMPONENT_DLL_FILES}" PARENT_SCOPE)
	set(_output_libraries "${_output_libraries}" PARENT_SCOPE)
	set(_BM_RENAME_ENABLED "${_BM_RENAME_ENABLED}" PARENT_SCOPE)
	set(_BM_BUILDONLY "${_BM_BUILDONLY}" PARENT_SCOPE)
	set(_BM_STRIPRES_ENABLED "${_BM_STRIPRES_ENABLED}" PARENT_SCOPE)
	set(_BM_PC_ENABLED "${_BM_PC_ENABLED}" PARENT_SCOPE)
	set(_BM_PC_NAME "${_BM_PC_NAME}" PARENT_SCOPE)
	set(_BM_PC_VERSION "${_BM_PC_VERSION}" PARENT_SCOPE)
	set(_BM_PC_DESCRIPTION "${_BM_PC_DESCRIPTION}" PARENT_SCOPE)
	set(_BM_PC_LIBS "${_BM_PC_LIBS}" PARENT_SCOPE)
	set(_BM_PC_REQUIRES "${_BM_PC_REQUIRES}" PARENT_SCOPE)
	set(_BM_PC_CFLAGS "${_BM_PC_CFLAGS}" PARENT_SCOPE)
	set(_BM_PC_OUT "${_BM_PC_OUT}" PARENT_SCOPE)
	set(_indent_level "${_indent_level}" PARENT_SCOPE)
	set(_toolchain "${_toolchain}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_collect_outputs")
endfunction()

## @brief configure_file + include the shared component fragment template.
## @param[in] _component Registered component id.
## @param[in] _deferred  TRUE → dependant template (configure at build time).
## @note Collects outputs, WHOLE, LINK (raw linker names), LINKFLAGS (raw
##       linker flags) and recorded dependencies, then generates
##       `component_<id>.cmake` under `BUILDMASTER_SCRIPTS_COMPONENTDIR`
##       and `include()`s it.
##       `<id>` is already an INTERFACE from create_*; the fragment only
##       attaches includes, IMPORTED archives, WHOLE, LINK and LINKFLAGS.
## @note `_BM_LINK_ITEMS` is the CMake list stored on
##       `BUILDMASTER_COMPONENT_<id>_LINK` (empty string if unset). The
##       template applies it INTERFACE on `<id>` so consumers propagate
##       those raw names to the final artefact.
## @note `_BM_LINKFLAGS_ITEMS` is the CMake list stored on
##       `BUILDMASTER_COMPONENT_<id>_LINKFLAGS` (empty string if unset).
##       The template applies it INTERFACE via `target_link_options`.
## @note Library-spec `buildmaster_link` dests are folded into FILES by
##       `collect_outputs`. Stage `OUTPUT` is frozen at create_* (declared
##       produced specs only). After `include()`, each extra file that is
##       not in that declared list gets:
##         add_custom_command(OUTPUT <file> DEPENDS <id>_install
##                            COMMAND ${CMAKE_COMMAND} -E true)
##       The command does not write the file. `<id>_install` writes it as
##       a side effect of the nested install. The rule exists so Ninja has
##       a producer for `<file>` when a host target links the IMPORTED
##       location. Do not drop this because Make passed locally.
## @note STRIPRES / WHOLE ignored on a non-static mode are INFO. STRIPRES
##       INFO only when the user wrote the key (default is ON).
function(_bm_comp_write_fragment _component _deferred)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_write_fragment")
	_bm_comp_collect_outputs("${_component}")

	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRODUCED)
	_bm_opt_parse(_il _toolchain _rn _bo _wh _sr "${_options_string}")
	if(_bo)
		set(_BM_BUILDONLY "1")
	else()
		set(_BM_BUILDONLY "0")
	endif()

	if(_sr AND NOT _library_mode STREQUAL "static")
		if("${_options_string}" MATCHES "[Ss][Tt][Rr][Ii][Pp][Rr][Ee][Ss]")
			_bm_log_message(COMPONENT INFO
				"STRIPRES ignored for '${_component}' (mode '${_library_mode}'; only static MSVC/clang-cl archives are stripped)")
		endif()
	endif()

	if(DEFINED BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND)
		set(ENV_CMAKE_SILENT_COMMAND ${BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND})
	endif()

	set(_LIBRARY_NAME "${_component}")
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	set(_LIBRARY_CONFIGURE_TARGET "${_component}_configure")
	set(_LIBRARY_BUILD_TARGET "${_component}_build")

	_bm_graph_dep_targets("${_component}" _LIBRARY_DEPENDENCIES)

	if(NOT _toolchain STREQUAL "")
		set(_LIBRARY_TOOLCHAIN_SUFFIX " (with toolchain ${_toolchain})")
	else()
		set(_LIBRARY_TOOLCHAIN_SUFFIX "")
	endif()

	set(_BM_WHOLE "0")
	set(_BM_WHOLE_LINK_ITEMS "")
	get_property(_whole_prop GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_WHOLE)
	if(_whole_prop)
		if(NOT _library_mode STREQUAL "static")
			_bm_log_message(COMPONENT INFO
				"WHOLE ignored for '${_component}' (mode '${_library_mode}'; only static is supported)")
		elseif(_LIBRARY_COMPONENT_FILES)
			set(_BM_WHOLE "1")
			_bm_opt_whole_items(_whole_list
				${_LIBRARY_COMPONENT_FILES})
			string(REPLACE ";" " " _BM_WHOLE_LINK_ITEMS "${_whole_list}")
		endif()
	endif()

	get_property(_BM_LINK_ITEMS GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_LINK)
	if(NOT _BM_LINK_ITEMS)
		set(_BM_LINK_ITEMS "")
	endif()
	if(_BM_LINK_ITEMS)
		_bm_log_message(COMPONENT DEBUG
			"${_component}: LINK (raw) → ${_BM_LINK_ITEMS}")
	endif()

	get_property(_BM_LINKFLAGS_ITEMS GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_LINKFLAGS)
	if(NOT _BM_LINKFLAGS_ITEMS)
		set(_BM_LINKFLAGS_ITEMS "")
	endif()
	if(_BM_LINKFLAGS_ITEMS)
		_bm_log_message(COMPONENT DEBUG
			"${_component}: LINKFLAGS (raw) → ${_BM_LINKFLAGS_ITEMS}")
	endif()

	if(_deferred)
		if(_library_mode STREQUAL "headers")
			set(_tpl "component_headers_dependant.cmake.in")
		elseif(_library_mode STREQUAL "shared")
			set(_tpl "component_shared_dependant.cmake.in")
		else()
			set(_tpl "component_static_dependant.cmake.in")
		endif()
	else()
		if(_library_mode STREQUAL "headers")
			set(_tpl "component_headers.cmake.in")
		elseif(_library_mode STREQUAL "shared")
			set(_tpl "component_shared.cmake.in")
		else()
			set(_tpl "component_static.cmake.in")
		endif()
	endif()

	_bm_path_sanitize(_safe "${_component}")
	set(_LIBRARY_CREATE_FILE
		"${BUILDMASTER_SCRIPTS_COMPONENTDIR}/component_${_safe}.cmake")

	configure_file(
		"${BUILDMASTER_COMPONENT_TEMPLATEDIR}/${_tpl}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)
	include("${_LIBRARY_CREATE_FILE}")

	if(NOT _library_mode STREQUAL "headers" AND TARGET "${_component}_install")
		set(_declared "")
		set(_base_libdir "${BUILDMASTER_INSTALL_LIBDIR}")
		if(_bo)
			get_property(_base_libdir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDDIR)
		endif()
		foreach(_spec IN LISTS _produced)
			if(_spec STREQUAL "")
				continue()
			endif()
			set(_pn "")
			set(_pf "")
			set(_pd "")
			_bm_opt_append_spec(
				"${_library_mode}" "${_spec}" "${_base_libdir}" _pn _pf _pd)
			list(APPEND _declared ${_pf} ${_pd})
		endforeach()
		foreach(_file IN LISTS _LIBRARY_COMPONENT_FILES _LIBRARY_COMPONENT_DLL_FILES)
			if(_file STREQUAL "")
				continue()
			endif()
			list(FIND _declared "${_file}" _hit)
			if(NOT _hit EQUAL -1)
				continue()
			endif()
			add_custom_command(
				OUTPUT "${_file}"
				COMMAND "${CMAKE_COMMAND}" -E true
				DEPENDS "${_component}_install"
				COMMENT "[BuildMaster/Ninja    ]: Waiting for ${_component}_install to publish ${_file}"
				VERBATIM
			)
			_bm_log_message(COMPONENT DEBUG
				"Ninja file rule for spec-link '${_file}' via '${_component}_install'")
		endforeach()
	endif()

	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_NAMES
		"${_LIBRARY_COMPONENT_NAMES}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES
		"${_LIBRARY_COMPONENT_FILES}")
	_bm_log_message(COMPONENT DEBUG "Wrote fragment ${_LIBRARY_CREATE_FILE} (${_tpl})")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_write_fragment")
endfunction()

## @brief Append one `-I<path>` token to backend configure OPTIONS.
## @param[in]     _sys      `cmake` or `meson`.
## @param[in,out] _opts_var Name of the CMake list of configure args.
## @param[in]     _tok      Token from `_bm_path_compile_include`.
## @note CMake: extends `-DCMAKE_C_FLAGS=` and `-DCMAKE_CXX_FLAGS=`
##       (creates them from cache/parent flags if missing). Meson:
##       extends `-Dc_args=` and `-Dcpp_args=`. Never writes ENV or a
##       native file. Several calls accumulate several `-I` in the same
##       `-D` value. Duplicate token in that value is a no-op.
function(_bm_comp_options_add_include _sys _opts_var _tok)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_options_add_include")
	if("${_tok}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_options_add_include: empty token")
	endif()
	if(NOT _sys STREQUAL "cmake" AND NOT _sys STREQUAL "meson")
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_options_add_include: sys '${_sys}' is not cmake/meson")
	endif()

	set(_opts "${${_opts_var}}")
	if(_sys STREQUAL "cmake")
		set(_keys "CMAKE_C_FLAGS;CMAKE_CXX_FLAGS")
	else()
		set(_keys "c_args;cpp_args")
	endif()

	foreach(_key IN LISTS _keys)
		set(_prefix "-D${_key}=")
		string(LENGTH "${_prefix}" _plen)
		set(_idx -1)
		set(_i 0)
		foreach(_item IN LISTS _opts)
			string(FIND "${_item}" "${_prefix}" _at)
			if(_at EQUAL 0)
				set(_idx ${_i})
				break()
			endif()
			math(EXPR _i "${_i} + 1")
		endforeach()

		if(_idx EQUAL -1)
			if(_sys STREQUAL "cmake")
				if(_key STREQUAL "CMAKE_C_FLAGS")
					set(_base "$CACHE{CMAKE_C_FLAGS}")
					if(_base STREQUAL "")
						set(_base "${CMAKE_C_FLAGS}")
					endif()
				else()
					set(_base "$CACHE{CMAKE_CXX_FLAGS}")
					if(_base STREQUAL "")
						set(_base "${CMAKE_CXX_FLAGS}")
					endif()
				endif()
				string(STRIP "${_base} ${_tok}" _val)
			else()
				set(_val "${_tok}")
			endif()
			list(APPEND _opts "${_prefix}${_val}")
		else()
			list(GET _opts ${_idx} _item)
			string(SUBSTRING "${_item}" ${_plen} -1 _val)
			string(FIND " ${_val} " " ${_tok} " _hit)
			if(_hit EQUAL -1)
				string(STRIP "${_val} ${_tok}" _val)
				list(REMOVE_AT _opts ${_idx})
				list(INSERT _opts ${_idx} "${_prefix}${_val}")
			endif()
		endif()
	endforeach()

	set(${_opts_var} "${_opts}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_options_add_include")
endfunction()

## @brief Append PRIVATE headers `-I` onto each direct linker's OPTIONS.
## @note Walks recorded `buildmaster_link` edges. Dest must be a registered
##       component with `PRIVATE_HEADERS` (backend `none`, or `BUILDONLY`
##       headers). Each such dest adds one `-I<srcdir>` token to the
##       source component OPTIONS (`CMAKE_*_FLAGS` / Meson `c_args`),
##       accumulated — several private headers ⇒ several `-I`.
## @note Does not write ENV, native file, runners, or INTERFACE. Skips a
##       source whose SYSTEM is `none` (no nested configure). Skips a dest
##       reached only through a meta (PRIVATE does not cross a meta).
## @note Must run before nested configure (start of `_bm_graph_finalize`).
function(_bm_comp_inject_private_headers)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_inject_private_headers")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
	if(NOT _srcs)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_inject_private_headers")
		return()
	endif()

	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")

		_bm_comp_is_registered("${_dst}" _dst_ok)
		if(NOT _dst_ok)
			continue()
		endif()
		get_property(_priv GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_PRIVATE_HEADERS)
		if(NOT _priv)
			continue()
		endif()

		_bm_comp_is_registered("${_src}" _src_ok)
		if(NOT _src_ok)
			continue()
		endif()
		get_property(_src_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_src}_SYSTEM)
		if(_src_sys STREQUAL "" OR _src_sys STREQUAL "none")
			continue()
		endif()

		get_property(_srcdir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_SRCDIR)
		_bm_path_compile_include(_tok "${_srcdir}")
		get_property(_opts GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_src}_OPTIONS)
		_bm_comp_options_add_include("${_src_sys}" _opts "${_tok}")
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_src}_OPTIONS "${_opts}")
		_bm_log_message(COMPONENT DEBUG
			"PRIVATE headers '${_dst}' → '${_src}' configure ${_tok}")
	endforeach()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_inject_private_headers")
endfunction()

## @brief Materialize a headers tree with no nested generate.
## @param[in] _component Registered id (`SYSTEM` is `none`).
## @note No cmake/meson stages. Creates empty `_configure` / `_build` /
##       `_install` so wait edges resolve. Stamp under BUILDDIR.
##       Does not INTERFACE-include the srcdir (PRIVATE headers: only
##       the direct linker's nested configure receives `-I`).
function(_bm_comp_none_materialize _component)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_none_materialize")
	get_property(_title GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_TITLE)
	get_property(_builddir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDDIR)
	get_property(_srcdir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_SRCDIR)

	if(NOT IS_DIRECTORY "${_srcdir}")
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_none_materialize('${_component}'): srcdir '${_srcdir}' is not a directory")
	endif()

	set(_stamp "${_builddir}/.bm_${_component}_headers.stamp")
	file(MAKE_DIRECTORY "${_builddir}")

	if(NOT TARGET "${_component}_configure")
		add_custom_target(${_component}_configure)
	endif()
	if(NOT TARGET "${_component}_build")
		add_custom_target(${_component}_build)
		add_dependencies(${_component}_build ${_component}_configure)
	endif()
	if(NOT TARGET "${_component}_install")
		add_custom_command(
			OUTPUT "${_stamp}"
			COMMAND "${CMAKE_COMMAND}" -E touch "${_stamp}"
			DEPENDS ${_component}_build
			COMMENT "[BuildMaster/Core     ]: Stamp headers ${_title}"
			VERBATIM)
		add_custom_target(${_component}_install DEPENDS "${_stamp}")
	endif()
	add_dependencies(${_component} ${_component}_install)

	_bm_hook_run_component("${_component}")

	_bm_log_message(COMPONENT DEBUG
		"Materialized headers-none ${_component} stamp=${_stamp}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_none_materialize")
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
function(_bm_comp_apply_links)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_apply_links")
	get_property(_lsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
	if(NOT _lsrcs)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_apply_links")
		return()
	endif()
	set(_i 0)
	foreach(_src IN LISTS _lsrcs)
		list(GET _ldsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")

		if(NOT TARGET "${_src}")
			_bm_log_message(COMPONENT FATAL
				"buildmaster_link: source '${_src}' is not a target (missing create_*_component?)")
		endif()

		_bm_meta_is("${_dst}" _dst_meta)
		if(_dst_meta)
			if(TARGET "${_dst}")
				target_link_libraries(${_src} INTERFACE ${_dst})
			endif()
			continue()
		endif()

		_bm_comp_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			get_property(_dst_priv GLOBAL PROPERTY
				BUILDMASTER_COMPONENT_${_dst}_PRIVATE_HEADERS)
			if(_dst_priv)
				_bm_log_message(COMPONENT DEBUG
					"buildmaster_link '${_src}' → PRIVATE headers '${_dst}' (no INTERFACE line)")
				continue()
			endif()
			_bm_comp_is_buildonly("${_dst}" _dst_bo)
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
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_apply_links")
endfunction()

## @brief Deferred materialize: metas, toolchain inherit, components, repacks,
##        links, orphan warn, hooks.
## @note Idempotent. Scheduled by `_bm_graph_defer_arm`; not public.
##       Harness may call this before configure-time contract checks.
## @note Concrete and create_meta INTERFACE stubs already exist. This pass
##       emits stages, fragments, headers-none stamps, repack targets, meta
##       stage anchors, member wiring and recorded `buildmaster_link` edges.
## @note Order: flush queued git reset/patch → inject PRIVATE headers
##       `-I` into linker OPTIONS → materialize metas → propagate meta
##       TOOLCHAIN → per-id cmake / meson / none materialize → repacks →
##       meta wire → apply links → orphan warning → fail if a per-id hook
##       was registered for an id that never materialized → graph hooks
##       (alias order).
## @note Git flush is first so eager nested configure sees patched sources.
## @note PRIVATE `-I` injection is before any nested configure so several
##       `buildmaster_link` edges to headers trees each add their own token.
## @note `SYSTEM=none` is headers without a backend (`_bm_comp_none_materialize`).
function(_bm_graph_finalize)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_finalize")
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_finalize")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED TRUE)

	if(COMMAND _bm_git_flush_all)
		_bm_git_flush_all()
	endif()

	_bm_comp_inject_private_headers()

	_bm_meta_materialize()
	_bm_tc_propagate_metas()

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		foreach(_id IN LISTS _ids)
			get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM)
			if(_sys STREQUAL "cmake")
				_bm_backend_cmake_materialize("${_id}")
			elseif(_sys STREQUAL "meson")
				_bm_backend_meson_materialize("${_id}")
			elseif(_sys STREQUAL "none")
				_bm_comp_none_materialize("${_id}")
			else()
				_bm_log_message(COMPONENT FATAL
					"finalize: unknown system '${_sys}' for '${_id}'")
			endif()
		endforeach()
	endif()

	_bm_repack_materialize()
	_bm_meta_wire()
	_bm_comp_apply_links()
	_bm_meta_warn_orphans()

	get_property(_hook_ids GLOBAL PROPERTY BUILDMASTER_ON_MATERIALIZE_IDS)
	if(_hook_ids)
		list(REMOVE_DUPLICATES _hook_ids)
		foreach(_hid IN LISTS _hook_ids)
			get_property(_hook_done GLOBAL PROPERTY
				BUILDMASTER_ON_MATERIALIZE_${_hid}_DONE)
			if(NOT _hook_done)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_hook_component('${_hid}'): component was never materialized")
			endif()
		endforeach()
	endif()

	_bm_hook_run_sorted("BUILDMASTER_ON_GRAPH_FINALIZED")

	_bm_log_message(COMPONENT DEBUG "Component graph finalized")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_finalize")
endfunction()
