# =============================================================================
# component/graph/create.cmake — _bm_graph_create
# =============================================================================

## @brief Register a component. Creates an empty INTERFACE `<id>` before return.
## @param[in] _component Short component identifier (INTERFACE target name).
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Backend source directory (after optstr `SOURCE=`).
##            GIT ops use `BUILDMASTER_COMPONENT_<id>_GIT_WORKDIR` when set
##            (positional srcdir / git work tree). Ignored when FILES SOURCE
##            supplies the tree (by design); the positional value is stored
##            only until apply rewrites SRCDIR.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _build_system `cmake`, `meson`, `none`, or `pending`.
##            `pending` means FILES SOURCE will unpack the tree and
##            autodetect runs after apply. `none` is valid for `headers`,
##            or for any mode when `NOINSTALL` is set (no nested generate).
## @param[in] _produced Primary library specs (`<name>` or `<subdir>/<name>`).
##            Empty for headers mode. Names are canonical (post-RENAME).
## @param[in] options_string Optional trailing "KEY=value;…" string.
##            Keys: INDENT / INDENT_LEVEL, TOOLCHAIN, RENAME (flag),
##            NOINSTALL (flag; do not publish to the shared prefix),
##            WHOLE (flag; static whole-archive link),
##            STRIPRES (flag; default ON; strip `.res` members from static
##            MSVC/clang-cl archives after RENAME),
##            LINK=<name> / LINK={name;name2} (raw linker names on the
##            component INTERFACE; see below),
##            LINKFLAGS=<flag> / LINKFLAGS={…} (raw linker flags folded
##            into this id's nested cmake/meson OPTIONS at finalize;
##            platform groups WINDOWS / LINUX / MAC / UNIX),
##            PC={VERSION=…;NAME=…;DESCRIPTION=…;ENABLED=…} (write a helper
##            `.pc` under the BM prefix for *internal* BM consumers),
##            GIT={…} (`ROOT=` is always under the git work tree), FILES={…},
##            REQUIRE_TOOL=… / REQUIRE_TOOL={…}.
## @note Build directory is `${CMAKE_CURRENT_BINARY_DIR}/bm/<id>`
##       (`_bm_path_component_builddir`). Created with `file(MAKE_DIRECTORY)`.
## @note `PRIVATE_HEADERS` is TRUE when `_build_system` is `none`, or when
##       `NOINSTALL` is set on a headers id. A source that does install may
##       wait on those dests (PRIVATE `-I` injection is not a prefix publish).
## @note The INTERFACE exists as soon as this function returns, so ALIAS /
##       target_* in the same CMakeLists (before DEFER) see `<id>`.
##       Deferred finalize only emits stages and the fragment. A second
##       `_bm_graph_create` for the same id is FATAL via `_bm_id_clash_fatal`
##       (first public-macro origin, `file:line`, when known).
## @note `_bm_tools_*_stages` is internal; backends call it from materialize
##       only.
## @note `LINK` items are external to BuildMaster (system / SDK libraries).
##       They are applied `INTERFACE` on `<id>` and propagate through CMake
##       `target_link_libraries` to the final artefact that consumes that id.
##       They do not repair a third-party archive that was linked without
##       going through this INTERFACE. Not a substitute for `buildmaster_link()`.
## @note `LINKFLAGS` items are external raw linker flags
##       (`/FORCE:MULTIPLE`, `-Wl,-Bsymbolic`). They are **not** placed on
##       the component INTERFACE. Finalize folds them into this id's
##       OPTIONS (`CMAKE_EXE/SHARED/MODULE_LINKER_FLAGS` for cmake,
##       `c_link_args` / `cpp_link_args` for meson) so only the nested
##       build sees them. Consumers that `target_link_libraries` this id
##       do not inherit those flags.
## @note Headers mode: `LINK` is INFO and ignored. `LINKFLAGS` is WARNING
##       and ignored (no nested link step).
## @note `STRIPRES` default is ON. INFO only when the user wrote the key and
##       mode is not static (shared/headers have nothing to strip).
## @note `PC={…}` with ENABLED=TRUE (default) requires VERSION. ENABLED=FALSE
##       skips VERSION and does not write a file. `NOINSTALL` + PC enabled is
##       FATAL (no shared prefix). `none` + PC enabled is FATAL. An upstream
##       `.pc` already at the canonical path is FATAL at install time (do not
##       clobber). Meta + PC is FATAL in `_bm_meta_impl`.
## @note GIT + FILES SOURCE is FATAL (two owners of the same tree).
## @note `SOURCE=` does not move the git work tree. GIT uses
##       `BUILDMASTER_COMPONENT_<id>_GIT_WORKDIR` (positional srcdir).
## @note `BUILDONLY` is removed; the parser FATALs (`use NOINSTALL`).
function(_bm_graph_create _component _component_title _srcdir
						_options _library_mode _build_system _produced)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_create")
	if(ARGC GREATER 8)
		_bm_log_message(COMPONENT FATAL
			"_bm_graph_create: too many arguments (expected at most one options string).")
	endif()

	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"_bm_graph_create('${_component}'): called after components were finalized")
	endif()

	if("${_component}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "_bm_graph_create: empty component id")
	endif()

	_bm_path_component_builddir(_builddir "${_component}")
	file(MAKE_DIRECTORY "${_builddir}")

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		list(FIND _ids "${_component}" _idx)
		if(NOT _idx EQUAL -1)
			_bm_id_clash_fatal("_bm_graph_create" "${_component}")
		endif()
	endif()

	_bm_meta_is("${_component}" _is_meta)
	if(_is_meta)
		_bm_id_clash_fatal("_bm_graph_create" "${_component}")
	endif()

	set(_options_string "")
	if(ARGC GREATER 7)
		set(_options_string "${ARGV7}")
	endif()

	_bm_opt_parse(
		_reg_indent _reg_tc _reg_rename _reg_noinstall _reg_whole _reg_stripres
		"${_options_string}")
	_bm_opt_parse_pc(
		"${_options_string}"
		_pc_present _pc_enabled _pc_name _pc_version _pc_description)
	_bm_opt_parse_link("${_options_string}" _reg_link)
	_bm_opt_parse_linkflags("${_options_string}" _reg_linkflags)
	_bm_opt_parse_repack("${_options_string}" _reg_repack)
	_bm_opt_parse_git(
		"${_options_string}" _git_present _git_fetch _git_switch _git_reset
		_git_patches _git_title _git_root)
	_bm_opt_parse_files(
		"${_options_string}" _files_present
		_files_urls _files_names _files_hashes _files_algos
		_files_unpacks _files_forces _files_sources _files_titles)
	_bm_opt_parse_require_tool("${_options_string}")
	if(_reg_repack)
		_bm_log_message(COMPONENT FATAL
			"REPACK is only valid on buildmaster_meta(). A component publishes its own artifacts; to merge several components into one archive, put REPACK on the meta and buildmaster_meta_add those ids.")
	endif()

	set(_files_has_source FALSE)
	foreach(_so IN LISTS _files_sources)
		if(NOT "${_so}" STREQUAL "")
			set(_files_has_source TRUE)
			break()
		endif()
	endforeach()
	if(_files_has_source AND _git_present AND
			(_git_fetch OR NOT "${_git_switch}" STREQUAL "" OR _git_reset OR _git_patches))
		_bm_log_message(COMPONENT FATAL
			"_bm_graph_create('${_component}'): GIT={…} cannot be combined with FILES SOURCE (two owners of the source tree)")
	endif()

	string(TOLOWER "${_library_mode}" _library_mode)
	string(TOLOWER "${_build_system}" _build_system)

	if(NOT _library_mode STREQUAL "static"
			AND NOT _library_mode STREQUAL "shared"
			AND NOT _library_mode STREQUAL "headers")
		_bm_log_message(COMPONENT FATAL
			"_bm_graph_create: unknown library mode '${_library_mode}' (expected static, shared, or headers)")
	endif()

	if(NOT _build_system STREQUAL "cmake"
			AND NOT _build_system STREQUAL "meson"
			AND NOT _build_system STREQUAL "none"
			AND NOT _build_system STREQUAL "pending")
		_bm_log_message(COMPONENT FATAL
			"_bm_graph_create: unknown build system '${_build_system}' (expected cmake, meson, none, or pending)")
	endif()

	if(_build_system STREQUAL "none" AND NOT _library_mode STREQUAL "headers")
		if(NOT _reg_noinstall)
			_bm_log_message(COMPONENT FATAL
				"_bm_graph_create('${_component}'): backend 'none' is only valid for headers, or with NOINSTALL")
		endif()
	endif()

	if(NOT _library_mode STREQUAL "headers")
		set(_has_prod FALSE)
		foreach(_spec IN LISTS _produced)
			if(NOT _spec STREQUAL "")
				set(_has_prod TRUE)
				break()
			endif()
		endforeach()
		if(NOT _has_prod)
			_bm_log_message(COMPONENT FATAL
				"_bm_graph_create '${_component}': static/shared mode requires at least one produced library spec")
		endif()
	endif()

	if("${_options_string}" MATCHES "[Ss][Tt][Rr][Ii][Pp][Rr][Ee][Ss]"
			AND NOT _library_mode STREQUAL "static")
		_bm_log_message(COMPONENT INFO
			"_bm_graph_create('${_component}'): STRIPRES ignored (mode '${_library_mode}'; only static MSVC/clang-cl archives are stripped)")
	endif()

	if(_library_mode STREQUAL "headers" AND _reg_link)
		_bm_log_message(COMPONENT INFO
			"_bm_graph_create('${_component}'): LINK ignored (headers mode has no link line)")
		set(_reg_link "")
	endif()
	if(_library_mode STREQUAL "headers" AND _reg_linkflags)
		_bm_log_message(COMPONENT WARNING
			"_bm_graph_create('${_component}'): LINKFLAGS ignored (headers mode has no link line)")
		set(_reg_linkflags "")
	endif()

	if(_pc_enabled AND (_reg_noinstall OR _build_system STREQUAL "none"))
		_bm_log_message(COMPONENT FATAL
			"_bm_graph_create('${_component}'): PC={…} cannot be used with NOINSTALL or a headers tree that does not install (helper .pc files are for internal consumers of the shared BM prefix)")
	endif()

	if(_pc_name STREQUAL "")
		set(_first_spec "")
		foreach(_spec IN LISTS _produced)
			if(NOT _spec STREQUAL "")
				set(_first_spec "${_spec}")
				break()
			endif()
		endforeach()
		if(NOT _first_spec STREQUAL "")
			_bm_opt_parse_spec("${_first_spec}" _ign_tgt _pc_name _ign_dir)
		else()
			set(_pc_name "${_component}")
		endif()
	endif()
	if(_pc_description STREQUAL "")
		set(_pc_description "${_component_title}")
	endif()

	if("${_options_string}" MATCHES "[Ww][Hh][Oo][Ll][Ee]"
			AND (_library_mode STREQUAL "headers" OR _build_system STREQUAL "none"))
		_bm_log_message(COMPONENT INFO
			"_bm_graph_create('${_component}'): WHOLE ignored (headers / no backend)")
		set(_reg_whole FALSE)
	endif()

	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_IDS "${_component}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_TITLE
		"${_component_title}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_SRCDIR
		"${_srcdir}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDDIR
		"${_builddir}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTIONS
		"${_options}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE
		"${_library_mode}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_SYSTEM
		"${_build_system}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRODUCED
		"${_produced}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR
		"${_options_string}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_LINK
		"${_reg_link}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_LINKFLAGS
		"${_reg_linkflags}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES_URLS
		"${_files_urls}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES_NAMES
		"${_files_names}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES_HASHES
		"${_files_hashes}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES_ALGOS
		"${_files_algos}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES_UNPACKS
		"${_files_unpacks}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES_FORCES
		"${_files_forces}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES_SOURCES
		"${_files_sources}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES_TITLES
		"${_files_titles}")
	if(_reg_noinstall)
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_NOINSTALL TRUE)
	else()
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_NOINSTALL FALSE)
	endif()
	if(_build_system STREQUAL "none" OR (_reg_noinstall AND _library_mode STREQUAL "headers"))
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRIVATE_HEADERS TRUE)
	else()
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRIVATE_HEADERS FALSE)
	endif()
	if(_reg_whole)
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_WHOLE TRUE)
	else()
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_WHOLE FALSE)
	endif()
	if(_reg_stripres AND _library_mode STREQUAL "static")
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_STRIPRES TRUE)
	else()
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_STRIPRES FALSE)
	endif()
	if(_pc_enabled)
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PC TRUE)
	else()
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PC FALSE)
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PC_NAME
		"${_pc_name}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PC_VERSION
		"${_pc_version}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PC_DESCRIPTION
		"${_pc_description}")

	add_library("${_component}" INTERFACE)

	get_property(_git_wd GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_GIT_WORKDIR)
	if("${_git_wd}" STREQUAL "")
		set(_git_wd "${_srcdir}")
	endif()
	_bm_comp_apply_git(
		"${_component}" "${_component_title}" "${_git_wd}" "${_options_string}")

	_bm_graph_defer_arm()
	_bm_log_message(COMPONENT DEBUG "Registered component ${_component} (${_build_system}/${_library_mode})")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_create")
endfunction()
