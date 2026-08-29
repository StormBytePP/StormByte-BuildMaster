# =============================================================================
# component/graph.cmake — registry and declarative graph
# =============================================================================
# _bm_comp_create, buildmaster_depend, buildmaster_link, buildmaster_prerequisite
# and the helpers that resolve edges. Materialize lives in materialize.cmake.

# =============================================================================
# Registry and declarative graph
# =============================================================================

## @brief Schedule deferred component materialization once per configure.
## @note Uses cmake_language(DEFER) on CMAKE_SOURCE_DIR so all create_* and
##       buildmaster_depend/link/repack calls in the tree are seen first.
##       Requires CMake >= 3.19.
function(_bm_graph_defer_arm)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_defer_arm")
	get_property(_armed GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEFER_ARMED)
	if(_armed)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_defer_arm")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEFER_ARMED TRUE)
	cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
		CALL _bm_graph_finalize)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_defer_arm")
endfunction()

## @brief Register a component. Creates an empty INTERFACE `<id>` before return.
## @param[in] _component Short component identifier (INTERFACE target name).
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory (created here if missing).
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _build_system `cmake` or `meson`.
## @param[in] _produced Primary library specs (`<name>` or `<subdir>/<name>`).
##            Empty for headers mode. Names are canonical (post-RENAME).
## @param[in] options_string Optional trailing "KEY=value;…" string.
##            Keys: INDENT / INDENT_LEVEL, TOOLCHAIN, RENAME (flag),
##            BUILDONLY (flag), WHOLE (flag; static whole-archive link),
##            STRIPRES (flag; default ON; strip `.res` members from static
##            MSVC/clang-cl archives after RENAME),
##            LINK=<name> / LINK={name;name2} (raw linker names on the
##            component INTERFACE; see below),
##            LINKFLAGS=<flag> / LINKFLAGS={…} (raw linker flags on the
##            component INTERFACE via target_link_options; platform groups
##            WINDOWS / LINUX / MAC / UNIX),
##            PC={VERSION=…;NAME=…;DESCRIPTION=…;ENABLED=…} (write a helper
##            `.pc` under the BM prefix for *internal* BM consumers).
## @note The INTERFACE exists as soon as this function returns, so ALIAS /
##       target_* in the same CMakeLists (before DEFER) see `<id>`.
##       Deferred finalize only emits stages and the fragment: includes,
##       IMPORTED archives, WHOLE, LINK and LINKFLAGS. A second create_*
##       for the same id is FATAL in the registry.
## @note `_builddir` is created with `file(MAKE_DIRECTORY)` (mkdir -p).
##       If the directory already exists that is fine. If it already has
##       contents, the caller owns mixed trees and the odd failures that
##       follow. Public `create_*` wrappers may pass a legacy caller path
##       or the canonical `_bm_comp_builddir` path.
## @note `LINK` items are external to BuildMaster (system / SDK libraries).
##       They are applied `INTERFACE` on `<id>` and propagate through CMake
##       `target_link_libraries` to the final artefact that consumes that id.
##       They do not repair a third-party archive that was linked without
##       going through this INTERFACE. Not a substitute for `buildmaster_link()`.
## @note `LINKFLAGS` items are external raw linker flags
##       (`/FORCE:MULTIPLE`, `-Wl,-Bsymbolic`). Applied `INTERFACE` on `<id>`
##       via `target_link_options` and propagate to the final artefact.
##       They do not rewrite the nested third-party link line.
## @note Headers mode: `LINK` is INFO and ignored. `LINKFLAGS` is WARNING
##       and ignored (no link line).
## @note `STRIPRES` default is ON. INFO only when the user wrote the key and
##       mode is not static (shared/headers have nothing to strip).
## @note `PC={…}` with ENABLED=TRUE (default) requires VERSION. ENABLED=FALSE
##       skips VERSION and does not write a file. BUILDONLY + PC enabled is
##       FATAL (no shared prefix). An upstream `.pc` already at the canonical
##       path is FATAL at install time (do not clobber). Meta + PC is FATAL
##       in buildmaster_meta.
## @note Does not return a fragment path and does not include() anything.
##       Prefer create_cmake_* / create_meson_* wrappers.
## @note create_*_stages is internal; backends call it from materialize only.
function(_bm_comp_create _component _component_title _srcdir _builddir
						_options _library_mode _build_system _produced)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_create")
	if(ARGC GREATER 9)
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_create: too many arguments (expected at most one options string).")
	endif()

	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_create('${_component}'): called after components were finalized")
	endif()

	if("${_component}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "_bm_comp_create: empty component id")
	endif()
	if("${_builddir}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_create('${_component}'): empty build directory")
	endif()
	file(MAKE_DIRECTORY "${_builddir}")

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		list(FIND _ids "${_component}" _idx)
		if(NOT _idx EQUAL -1)
			_bm_log_message(COMPONENT FATAL
				"_bm_comp_create: duplicate id '${_component}'")
		endif()
	endif()

	_bm_meta_is("${_component}" _is_meta)
	if(_is_meta)
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_create: '${_component}' is already a meta id")
	endif()

	set(_options_string "")
	if(ARGC GREATER 8)
		set(_options_string "${ARGV8}")
	endif()

	_bm_opt_parse(
		_reg_indent _reg_tc _reg_rename _reg_buildonly _reg_whole _reg_stripres
		"${_options_string}")
	_bm_opt_parse_pc(
		"${_options_string}"
		_pc_present _pc_enabled _pc_name _pc_version _pc_description)
	_bm_opt_parse_link("${_options_string}" _reg_link)
	_bm_opt_parse_linkflags("${_options_string}" _reg_linkflags)

	string(TOLOWER "${_library_mode}" _library_mode)
	string(TOLOWER "${_build_system}" _build_system)

	if(NOT _library_mode STREQUAL "static"
			AND NOT _library_mode STREQUAL "shared"
			AND NOT _library_mode STREQUAL "headers")
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_create: unknown library mode '${_library_mode}' (expected static, shared, or headers)")
	endif()

	if(NOT _build_system STREQUAL "cmake" AND NOT _build_system STREQUAL "meson")
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_create: unknown build system '${_build_system}' (expected cmake or meson)")
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
				"_bm_comp_create '${_component}': static/shared mode requires at least one produced library spec")
		endif()
	endif()

	if("${_options_string}" MATCHES "[Ss][Tt][Rr][Ii][Pp][Rr][Ee][Ss]"
			AND NOT _library_mode STREQUAL "static")
		_bm_log_message(COMPONENT INFO
			"_bm_comp_create('${_component}'): STRIPRES ignored (mode '${_library_mode}'; only static MSVC/clang-cl archives are stripped)")
	endif()

	if(_library_mode STREQUAL "headers" AND _reg_link)
		_bm_log_message(COMPONENT INFO
			"_bm_comp_create('${_component}'): LINK ignored (headers mode has no link line)")
		set(_reg_link "")
	endif()
	if(_library_mode STREQUAL "headers" AND _reg_linkflags)
		_bm_log_message(COMPONENT WARNING
			"_bm_comp_create('${_component}'): LINKFLAGS ignored (headers mode has no link line)")
		set(_reg_linkflags "")
	endif()

	if(_pc_enabled AND _reg_buildonly)
		_bm_log_message(COMPONENT FATAL
			"_bm_comp_create('${_component}'): PC={…} cannot be used with BUILDONLY (helper .pc files are for internal consumers of the shared BM prefix)")
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
	if(_reg_buildonly)
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDONLY TRUE)
	else()
		set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDONLY FALSE)
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

	_bm_comp_apply_git(
		"${_component}" "${_component_title}" "${_srcdir}" "${_options_string}")

	_bm_graph_defer_arm()
	_bm_log_message(COMPONENT DEBUG "Registered component ${_component} (${_build_system}/${_library_mode})")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_create")
endfunction()

## @brief Whether `(source, dest)` is already stored in two parallel GLOBAL lists.
## @param[in]  _srcs_prop Property name of sources.
## @param[in]  _dsts_prop Property name of dests (same length, same order).
## @param[in]  source     Left side of the pair.
## @param[in]  dest       Right side of the pair.
## @param[out] out_var    Parent-scope TRUE if the pair exists.
function(_bm_graph_pair_in_lists _srcs_prop _dsts_prop source dest out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_pair_in_lists")
	get_property(_srcs GLOBAL PROPERTY ${_srcs_prop})
	get_property(_dsts GLOBAL PROPERTY ${_dsts_prop})
	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")
		if(_src STREQUAL "${source}" AND _dst STREQUAL "${dest}")
			set(${out_var} TRUE PARENT_SCOPE)
			_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_pair_in_lists")
			return()
		endif()
	endforeach()
	set(${out_var} FALSE PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_pair_in_lists")
endfunction()

## @brief Record an order-only edge if the pair is new. No user WARNING.
## @param[in] source Component id or CMake target (resolved at finalize).
## @param[in] dest   Component id, meta, stage, or existing target.
## @note Called from `buildmaster_link` (auto-dep) and from public
##       `buildmaster_depend` after the duplicate check. A second
##       internal record of the same pair is a silent no-op.
function(_bm_graph_record_dep source dest)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_record_dep")
	_bm_graph_pair_in_lists(
		BUILDMASTER_COMPONENT_DEP_SOURCES
		BUILDMASTER_COMPONENT_DEP_DESTS
		"${source}" "${dest}" _have)
	if(_have)
		_bm_log_message(COMPONENT DEBUG
			"record_dependency ${source} → ${dest} (already present)")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_record_dep")
		return()
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES
		"${source}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS
		"${dest}")
	_bm_graph_defer_arm()
	_bm_log_message(COMPONENT DEBUG "record_dependency ${source} → ${dest}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_record_dep")
endfunction()

## @brief Declare an order-only edge (no link line).
## @param[in] source Component id or CMake target (resolved at finalize).
## @param[in] dest   Component id (→ `<dest>_install`), meta id, existing target,
##            or `<id>_install` / `<id>_configure` / `<id>_build`.
## @note A non-BUILDONLY component must not depend on a BUILDONLY component
##       (checked at materialize). BUILDONLY may depend on BUILDONLY or normal.
## @note May be called before either endpoint exists; edges are recorded and
##       resolved in `_bm_graph_finalize`.
## @note A second explicit call with the same `(source, dest)` is WARNING and
##       a no-op (including when `buildmaster_link` already recorded the pair).
##       Unresolvable dest at finalize stays FATAL.
function(buildmaster_depend source dest)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_depend")
	if(ARGC GREATER 2)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_depend: expected exactly two arguments")
	endif()
	if("${source}" STREQUAL "" OR "${dest}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_depend: source and dest must be non-empty")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_depend: called after finalize")
	endif()
	_bm_graph_pair_in_lists(
		BUILDMASTER_COMPONENT_DEP_SOURCES
		BUILDMASTER_COMPONENT_DEP_DESTS
		"${source}" "${dest}" _have)
	if(_have)
		_bm_log_message(COMPONENT WARNING
			"buildmaster_depend('${source}', '${dest}'): edge already recorded — extra call ignored")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_depend")
		return()
	endif()
	_bm_graph_record_dep("${source}" "${dest}")
	_bm_log_message(COMPONENT DEBUG "buildmaster_depend ${source} → ${dest}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_depend")
endfunction()

## @brief Declare a link from a component (and order when dest is a graph node).
## @param[in] source Registered component id (INTERFACE from create_*).
## @param[in] dest   Registered component or meta, existing CMake target,
##            an on-disk archive path, or a library spec
##            (`<name>` or `<subdir>/<name>`) under the BM prefix.
## @note Dest that is none of the above is FATAL at materialize. Raw system
##       linker names (`shlwapi`, `ws2_32`) belong in `LINK=` / `LINK={…}`
##       on the producer, not here.
## @note A spec dest is resolved with the source component’s mode against
##       `BUILDMASTER_INSTALL_LIBDIR`. The archive need not exist yet.
## @note Linking to a BUILDONLY component is FATAL at materialize.
## @note buildmaster_link only participates in the BuildMaster graph; host app
##       targets use target_link_libraries(… PRIVATE <component_id>).
## @note Always records an order-only edge via `_bm_graph_record_dep`
##       so `buildmaster_link(A B)` before `create_*(B)` still defers A.
##       A second explicit `buildmaster_link` with the same pair is WARNING
##       and a no-op. The auto-dependency does not WARN.
function(buildmaster_link source dest)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_link")
	if(ARGC GREATER 2)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_link: expected exactly two arguments")
	endif()
	if("${source}" STREQUAL "" OR "${dest}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_link: source and dest must be non-empty")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_link: called after finalize")
	endif()
	_bm_graph_pair_in_lists(
		BUILDMASTER_COMPONENT_LINK_SOURCES
		BUILDMASTER_COMPONENT_LINK_DESTS
		"${source}" "${dest}" _have)
	if(_have)
		_bm_log_message(COMPONENT WARNING
			"buildmaster_link('${source}', '${dest}'): edge already recorded — extra call ignored")
		_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_link")
		return()
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES
		"${source}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS
		"${dest}")

	_bm_graph_record_dep("${source}" "${dest}")

	_bm_graph_defer_arm()
	_bm_log_message(COMPONENT DEBUG "buildmaster_link ${source} → ${dest}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_link")
endfunction()

## @brief Declare a custom prerequisite target (download, unpack, codegen, …).
## @param[in] name Target name (must not already exist as a CMake target).
## @param[in] COMMAND  One or more command argv tokens.
## @param[in] COMMENT  Optional progress text (wrapped with the Component header).
## @param[in] WORKING_DIRECTORY Optional working directory.
## @param[in] SCRIPT   Optional path to a CMake -P script.
## @param[in] DEPENDS  Optional list of CMake targets this prerequisite waits on.
## @note Creates an `add_custom_target`. Other components wait on it via
##       `buildmaster_depend(<id> <name>)`.
## @note If SCRIPT is set and COMMAND is not, COMMAND becomes
##       `${CMAKE_COMMAND} -P <SCRIPT>`.
function(buildmaster_prerequisite name)
	_bm_log_message(COMPONENT LOWLEVEL "Entering buildmaster_prerequisite")
	if("${name}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_prerequisite: empty name")
	endif()
	if(TARGET "${name}")
		_bm_log_message(COMPONENT FATAL
			"buildmaster_prerequisite: target '${name}' already exists")
	endif()

	cmake_parse_arguments(ARG
		""
		"COMMENT;WORKING_DIRECTORY;SCRIPT"
		"COMMAND;DEPENDS"
		${ARGN}
	)

	if(ARG_SCRIPT AND NOT ARG_COMMAND)
		set(ARG_COMMAND "${CMAKE_COMMAND}" -P "${ARG_SCRIPT}")
	endif()
	if(NOT ARG_COMMAND)
		_bm_log_message(COMPONENT FATAL
			"buildmaster_prerequisite('${name}'): need COMMAND and/or SCRIPT")
	endif()
	if(NOT ARG_COMMENT)
		set(ARG_COMMENT "prerequisite: ${name}")
	endif()
	if(COMMAND _bm_log_comment)
		_bm_log_comment(_bm_cmt COMPONENT "${ARG_COMMENT}")
	else()
		set(_bm_cmt "[BuildMaster/Component]: ${ARG_COMMENT}")
	endif()

	set(_wd_args "")
	if(ARG_WORKING_DIRECTORY)
		set(_wd_args WORKING_DIRECTORY "${ARG_WORKING_DIRECTORY}")
	endif()

	add_custom_target(${name}
		COMMAND ${ARG_COMMAND}
		COMMENT "${_bm_cmt}"
		${_wd_args}
		USES_TERMINAL
		VERBATIM
	)

	if(ARG_DEPENDS)
		add_dependencies(${name} ${ARG_DEPENDS})
	endif()

	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_PREREQUISITE_IDS "${name}")
	_bm_log_message(COMPONENT DEBUG "prerequisite target ${name}")
	_bm_log_message(COMPONENT LOWLEVEL "Exiting buildmaster_prerequisite")
endfunction()

## @brief Whether `id` was registered with _bm_comp_create.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE/FALSE.
## @note Meta ids are not included; use `_bm_meta_is()`.
function(_bm_comp_is_registered id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_is_registered")
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		list(FIND _ids "${id}" _idx)
		if(NOT _idx EQUAL -1)
			set(${out_var} TRUE PARENT_SCOPE)
			_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_is_registered")
			return()
		endif()
	endif()
	set(${out_var} FALSE PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_is_registered")
endfunction()

## @brief Whether a registered component is BUILDONLY.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE if the BUILDONLY flag is set, else FALSE.
## @note Unregistered ids yield FALSE (property unset).
function(_bm_comp_is_buildonly id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_is_buildonly")
	get_property(_bo GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_BUILDONLY)
	if(_bo)
		set(${out_var} TRUE PARENT_SCOPE)
	else()
		set(${out_var} FALSE PARENT_SCOPE)
	endif()
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_is_buildonly")
endfunction()

## @brief Whether this component must use build-time configure.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE if `id` appears as a dependency source.
## @note Configure-time configure is used when the component has no recorded
##       incoming edges; otherwise configure runs as a build step (dependant
##       template) so artifacts from dest can exist first.
function(_bm_comp_has_deferred_configure id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_comp_has_deferred_configure")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	if(_srcs)
		list(FIND _srcs "${id}" _idx)
		if(NOT _idx EQUAL -1)
			set(${out_var} TRUE PARENT_SCOPE)
			_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_has_deferred_configure")
			return()
		endif()
	endif()
	set(${out_var} FALSE PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_comp_has_deferred_configure")
endfunction()

## @brief Resolve one dependency dest to a CMake target name.
## @param[in]  dest    Component id, meta id, stage name, or existing target.
## @param[out] out_tgt Resolved target (e.g. `<id>_install`).
## @param[out] out_ok  TRUE if dest resolved.
## @note Resolution order: registered component → meta → `*_install` /
##       `*_configure` / `*_build` → existing CMake target.
function(_bm_graph_resolve_dest dest out_tgt out_ok)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_resolve_dest")
	_bm_comp_is_registered("${dest}" _is_comp)
	if(_is_comp)
		set(${out_tgt} "${dest}_install" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
		return()
	endif()
	_bm_meta_is("${dest}" _is_meta)
	if(_is_meta)
		set(${out_tgt} "${dest}_install" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
		return()
	endif()
	if("${dest}" MATCHES "^(.+)_(install|configure|build)$")
		set(${out_tgt} "${dest}" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
		return()
	endif()
	if(TARGET "${dest}")
		set(${out_tgt} "${dest}" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
		return()
	endif()
	set(${out_tgt} "" PARENT_SCOPE)
	set(${out_ok} FALSE PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_resolve_dest")
endfunction()

## @brief Space-separated prerequisite targets for the dependant template.
## @param[in]  id      Component whose outgoing dependency edges are collected.
## @param[out] out_var Parent-scope string of unique target names, space-joined
##            (empty if this component has no recorded dests).
## @note FATAL if dest cannot be resolved, unless the same pair is also a
##       `buildmaster_link` (spec or on-disk archive: link-only, no wait target).
##       FATAL if a non-BUILDONLY `id` depends on a BUILDONLY dest.
function(_bm_graph_dep_targets id out_var)
	_bm_log_message(COMPONENT LOWLEVEL "Entering _bm_graph_dep_targets")
	set(_dep_targets "")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	_bm_comp_is_buildonly("${id}" _src_bo)

	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")
		if(NOT _src STREQUAL "${id}")
			continue()
		endif()

		_bm_comp_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			_bm_comp_is_buildonly("${_dst}" _dst_bo)
			if(_dst_bo AND NOT _src_bo)
				_bm_log_message(COMPONENT FATAL
					"buildmaster_depend('${id}', '${_dst}'): a non-BUILDONLY component cannot depend on BUILDONLY '${_dst}' (use buildmaster_repack to publish, or make '${id}' BUILDONLY too)")
			endif()
		endif()

		_bm_graph_resolve_dest("${_dst}" _tgt _ok)
		if(NOT _ok)
			_bm_graph_pair_in_lists(
				BUILDMASTER_COMPONENT_LINK_SOURCES
				BUILDMASTER_COMPONENT_LINK_DESTS
				"${id}" "${_dst}" _also_link)
			if(_also_link)
				_bm_log_message(COMPONENT DEBUG
					"buildmaster_depend('${id}', '${_dst}'): dest is link-only (spec or archive), no wait target")
				continue()
			endif()
			_bm_log_message(COMPONENT FATAL
				"buildmaster_depend('${id}', '${_dst}'): cannot resolve dest. Accepted: registered component id → <id>_install; meta id → <id>_install; <id>_install / _configure / _build; existing CMake target (e.g. buildmaster_prerequisite / file_* target).")
		endif()
		list(APPEND _dep_targets "${_tgt}")
	endforeach()
	if(_dep_targets)
		list(REMOVE_DUPLICATES _dep_targets)
	endif()
	string(REPLACE ";" " " _joined "${_dep_targets}")
	set(${out_var} "${_joined}" PARENT_SCOPE)
	_bm_log_message(COMPONENT LOWLEVEL "Exiting _bm_graph_dep_targets")
endfunction()
