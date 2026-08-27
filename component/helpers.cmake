# =============================================================================
# component/helpers.cmake — registry, graph, shared fragment emit
# =============================================================================
# Public: create_component, component_dependency, component_link,
#         component_prerequisite, component_repack (see repack.cmake),
#         create_meta_component / meta_component_add (see meta.cmake).
# Backends (component/cmake, component/meson) own create_*_stages and
# _buildmaster_materialize_{cmake,meson}.
# Nested bootstrap that only include()s this file still loads the wrappers.

include("${CMAKE_CURRENT_LIST_DIR}/../log.cmake")

## @brief Keys that may appear without '=' (flag form → enabled).
set(BUILDMASTER_COMPONENT_OPTION_FLAGS "RENAME;BUILDONLY;WHOLE")

## @brief Split one options token into key and value.
## @param[in]  pair     Raw token (KEY=value, KEY=, or KEY for flags).
## @param[out] out_key  Uppercase stripped key (parent scope).
## @param[out] out_val  Value (may be empty).
## @param[out] out_ok   TRUE if the token is usable.
## @note Tokens without '=' are only accepted when the key is listed in
##       BUILDMASTER_COMPONENT_OPTION_FLAGS (e.g. RENAME ≡ RENAME=ON).
function(buildmaster_option_pair_split pair out_key out_val out_ok)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_option_pair_split")
	set(_ok TRUE)
	set(_key "")
	set(_val "")

	if("${pair}" STREQUAL "")
		set(_ok FALSE)
	else()
		string(FIND "${pair}" "=" _eq_pos)
		if(_eq_pos EQUAL -1)
			string(STRIP "${pair}" _key)
			string(TOUPPER "${_key}" _key)
			set(_is_flag FALSE)
			foreach(_f IN LISTS BUILDMASTER_COMPONENT_OPTION_FLAGS)
				if(_key STREQUAL "${_f}")
					set(_is_flag TRUE)
					break()
				endif()
			endforeach()
			if(_is_flag)
				set(_val "")
			else()
				buildmaster_message(COMPONENT WARNING
					"Option '${pair}' requires KEY=value form (ignored)")
				set(_ok FALSE)
			endif()
		else()
			string(SUBSTRING "${pair}" 0 ${_eq_pos} _key)
			math(EXPR _val_start "${_eq_pos} + 1")
			string(SUBSTRING "${pair}" ${_val_start} -1 _val)
			string(STRIP "${_key}" _key)
			string(TOUPPER "${_key}" _key)
			string(STRIP "${_val}" _val)
		endif()
	endif()

	set(${out_key} "${_key}" PARENT_SCOPE)
	set(${out_val} "${_val}" PARENT_SCOPE)
	set(${out_ok} "${_ok}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_option_pair_split")
endfunction()

## @brief Interpret a flag option value.
## @param[in]  val      Empty (flag form), or ON/OFF-style string.
## @param[out] out_bool Parent-scope TRUE/FALSE.
## @note Empty value means enabled (RENAME ≡ RENAME=ON ≡ RENAME=).
function(buildmaster_option_flag_enabled val out_bool)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_option_flag_enabled")
	if("${val}" STREQUAL "")
		set(${out_bool} TRUE PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_option_flag_enabled")
		return()
	endif()
	string(TOUPPER "${val}" _v)
	if(_v STREQUAL "1" OR _v STREQUAL "ON" OR _v STREQUAL "TRUE" OR _v STREQUAL "YES")
		set(${out_bool} TRUE PARENT_SCOPE)
	elseif(_v STREQUAL "0" OR _v STREQUAL "OFF" OR _v STREQUAL "FALSE" OR _v STREQUAL "NO")
		set(${out_bool} FALSE PARENT_SCOPE)
	else()
		buildmaster_message(COMPONENT WARNING
			"Unrecognized flag value '${val}' (treated as OFF)")
		set(${out_bool} FALSE PARENT_SCOPE)
	endif()
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_option_flag_enabled")
endfunction()

## @brief Parse the optional KEY=VALUE;… options string used by create_*_component.
## @param[out] out_indent     Indent level (integer, default 0).
## @param[out] out_toolchain  Toolchain name (empty = inherit).
## @param[out] out_rename     TRUE/FALSE — normalize variant names (default TRUE).
## @param[out] out_buildonly  TRUE/FALSE — build without installing to the shared
##            prefix (default FALSE). Artifacts live under the component BUILDDIR
##            only; RENAME runs in that tree after build.
## @param[out] out_whole      TRUE/FALSE — link produced statics with whole-archive
##            semantics (default FALSE). Only meaningful for static mode;
##            shared/headers → WARNING and ignored at materialize.
## @param[in]  options_string Optional "KEY=value;KEY2=…" string.
## @note Flag keys listed in BUILDMASTER_COMPONENT_OPTION_FLAGS may omit '='.
##       Unknown keys → WARNING. LINK_EXTRA is removed; use component_link().
function(buildmaster_parse_component_options out_indent out_toolchain out_rename
											out_buildonly out_whole options_string)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_parse_component_options")
	set(_indent 0)
	set(_toolchain "")
	set(_rename TRUE)
	set(_buildonly FALSE)
	set(_whole FALSE)

	if(NOT "${options_string}" STREQUAL "")
		string(REPLACE ";" "\n" _tmp "${options_string}")
		string(REPLACE "\n" ";" _pairs "${_tmp}")

		foreach(_pair IN LISTS _pairs)
			if(_pair STREQUAL "")
				continue()
			endif()

			buildmaster_option_pair_split("${_pair}" _key _val _ok)
			if(NOT _ok)
				continue()
			endif()

			if(_key STREQUAL "INDENT" OR _key STREQUAL "INDENT_LEVEL")
				if(_val MATCHES "^[0-9]+$")
					set(_indent "${_val}")
				else()
					buildmaster_message(COMPONENT WARNING
						"INDENT must be a non-negative integer, got '${_val}'")
				endif()
			elseif(_key STREQUAL "TOOLCHAIN")
				set(_toolchain "${_val}")
			elseif(_key STREQUAL "LINK_EXTRA")
				buildmaster_message(COMPONENT WARNING
					"LINK_EXTRA is removed; use component_link() (ignored)")
			elseif(_key STREQUAL "RENAME")
				buildmaster_option_flag_enabled("${_val}" _rename)
			elseif(_key STREQUAL "BUILDONLY")
				buildmaster_option_flag_enabled("${_val}" _buildonly)
			elseif(_key STREQUAL "WHOLE")
				buildmaster_option_flag_enabled("${_val}" _whole)
			else()
				buildmaster_message(COMPONENT WARNING
					"Unknown component option '${_key}' (ignored)")
			endif()
		endforeach()
	endif()

	set(${out_indent} "${_indent}" PARENT_SCOPE)
	set(${out_toolchain} "${_toolchain}" PARENT_SCOPE)
	set(${out_rename} "${_rename}" PARENT_SCOPE)
	set(${out_buildonly} "${_buildonly}" PARENT_SCOPE)
	set(${out_whole} "${_whole}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_parse_component_options")
endfunction()

## @brief Split a library spec into CMake target, library basename and libdir subdir.
## @param[in]  spec        Either `<name>` or `<subdir>/<name>`.
## @param[out] out_target  Imported CMake target name (`/` → `_`).
## @param[out] out_libname Library basename without prefix/suffix.
## @param[out] out_subdir  Directory relative to the library base dir, or empty.
function(buildmaster_parse_subcomponent spec out_target out_libname out_subdir)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_parse_subcomponent")
	if("${spec}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL
			"buildmaster_parse_subcomponent: empty library spec")
	endif()

	string(FIND "${spec}" "/" _slash)
	if(_slash EQUAL -1)
		set(_tgt "${spec}")
		set(_name "${spec}")
		set(_dir "")
	else()
		get_filename_component(_name "${spec}" NAME)
		get_filename_component(_dir "${spec}" DIRECTORY)
		string(REPLACE "/" "_" _tgt "${spec}")
	endif()

	if("${_name}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL
			"buildmaster_parse_subcomponent: missing library name in '${spec}'")
	endif()

	set(${out_target} "${_tgt}" PARENT_SCOPE)
	set(${out_libname} "${_name}" PARENT_SCOPE)
	set(${out_subdir} "${_dir}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_parse_subcomponent")
endfunction()

## @brief Resolve one library spec into IMPORTED name + file path (+ MSVC DLL).
## @param[in]  library_mode `static` or `shared`.
## @param[in]  spec         Library spec (`<name>` or `<subdir>/<name>`).
## @param[in]  base_libdir  Root for archives (BUILDMASTER_INSTALL_LIBDIR, or the
##            component BUILDDIR when BUILDONLY).
## @param[out] names_var    List variable receiving the imported target name.
## @param[out] files_var    List variable receiving the archive/import path.
## @param[out] dlls_var     List variable receiving the MSVC DLL path (shared only).
## @note BUILDONLY must pass the component's own BUILDDIR — never the parent
##       install prefix or another component's build tree.
macro(buildmaster_append_library_spec library_mode spec base_libdir
									names_var files_var dlls_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering buildmaster_append_library_spec")
	buildmaster_parse_subcomponent("${spec}" _bm_as_tgt _bm_as_name _bm_as_subdir)
	list(APPEND ${names_var} "${_bm_as_tgt}")
	if("${library_mode}" STREQUAL "static")
		library_import_static_hint(_bm_as_path "${_bm_as_name}"
			"${base_libdir}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
	else()
		library_import_hint(_bm_as_path "${_bm_as_name}"
			"${base_libdir}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
		if(MSVC)
			list(APPEND ${dlls_var}
				"${base_libdir}/${_bm_as_name}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		endif()
	endif()
	buildmaster_message(COMPONENT LOWLEVEL "Exiting buildmaster_append_library_spec")
endmacro()

## @brief Build whole-archive linker items for a list of static archive paths.
## @param[out] _out_var Name of the parent-scope variable to receive the item list.
## @param[in]  ARGN     Absolute (or install-relative) static archive paths.
##
## One closed region per component on ELF; per-archive force_load / WHOLEARCHIVE
## on Apple / MSVC. MSVC uses -WHOLEARCHIVE: so CMake/Ninja do not treat the
## token as a filesystem path (leading /WHOLEARCHIVE: is parsed as a file).
function(_buildmaster_whole_archive_link_items _out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_whole_archive_link_items")
	set(_paths ${ARGN})
	set(_items "")
	if(NOT _paths)
		set(${_out_var} "" PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_whole_archive_link_items")
		return()
	endif()
	if(MSVC)
		foreach(_p IN LISTS _paths)
			list(APPEND _items "-WHOLEARCHIVE:${_p}")
		endforeach()
	elseif(APPLE)
		foreach(_p IN LISTS _paths)
			list(APPEND _items "-Wl,-force_load,${_p}")
		endforeach()
	else()
		list(APPEND _items "-Wl,--whole-archive")
		foreach(_p IN LISTS _paths)
			list(APPEND _items "${_p}")
		endforeach()
		list(APPEND _items "-Wl,--no-whole-archive")
	endif()
	set(${_out_var} "${_items}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_whole_archive_link_items")
endfunction()

# =============================================================================
# Registry and declarative graph
# =============================================================================

## @brief Schedule deferred component materialization once per configure.
## @note Uses cmake_language(DEFER) on CMAKE_SOURCE_DIR so all create_* and
##       component_dependency/link/repack calls in the tree are seen first.
##       Requires CMake >= 3.19.
function(_buildmaster_component_defer_arm)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_defer_arm")
	get_property(_armed GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEFER_ARMED)
	if(_armed)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_defer_arm")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEFER_ARMED TRUE)
	cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
		CALL _buildmaster_finalize_components)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_defer_arm")
endfunction()

## @brief Register a component. Targets are created at deferred finalize.
## @param[in] _component Short component identifier (INTERFACE target name).
## @param[in] _component_title Human-readable title.
## @param[in] _srcdir Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _options Options forwarded to internal stage generators.
## @param[in] _library_mode `static`, `shared`, or `headers`.
## @param[in] _build_system `cmake` or `meson`.
## @param[in] _produced Primary library specs (`<name>` or `<subdir>/<name>`).
##            Empty for headers mode. Names are canonical (post-RENAME).
## @param[in] options_string Optional trailing "KEY=value;…" string.
##            Keys: INDENT / INDENT_LEVEL, TOOLCHAIN, RENAME (flag),
##            BUILDONLY (flag), WHOLE (flag; static whole-archive link).
## @note Does not return a fragment path and does not include() anything.
##       Prefer create_cmake_* / create_meson_* wrappers.
## @note create_*_stages is internal; backends call it from materialize only.
function(create_component _component _component_title _srcdir _builddir
						_options _library_mode _build_system _produced)
	buildmaster_message(COMPONENT LOWLEVEL "Entering create_component")
	if(ARGC GREATER 9)
		buildmaster_message(COMPONENT FATAL
			"create_component: too many arguments (expected at most one options string).")
	endif()

	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		buildmaster_message(COMPONENT FATAL
			"create_component('${_component}'): called after components were finalized")
	endif()

	if("${_component}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL "create_component: empty component id")
	endif()

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		list(FIND _ids "${_component}" _idx)
		if(NOT _idx EQUAL -1)
			buildmaster_message(COMPONENT FATAL
				"create_component: duplicate id '${_component}'")
		endif()
	endif()

	_buildmaster_meta_is("${_component}" _is_meta)
	if(_is_meta)
		buildmaster_message(COMPONENT FATAL
			"create_component: '${_component}' is already a meta id")
	endif()

	set(_options_string "")
	if(ARGC GREATER 8)
		set(_options_string "${ARGV8}")
	endif()

	buildmaster_parse_component_options(
		_reg_indent _reg_tc _reg_rename _reg_buildonly _reg_whole
		"${_options_string}")

	string(TOLOWER "${_library_mode}" _library_mode)
	string(TOLOWER "${_build_system}" _build_system)

	if(NOT _library_mode STREQUAL "static"
			AND NOT _library_mode STREQUAL "shared"
			AND NOT _library_mode STREQUAL "headers")
		buildmaster_message(COMPONENT FATAL
			"create_component: unknown library mode '${_library_mode}' (expected static, shared, or headers)")
	endif()

	if(NOT _build_system STREQUAL "cmake" AND NOT _build_system STREQUAL "meson")
		buildmaster_message(COMPONENT FATAL
			"create_component: unknown build system '${_build_system}' (expected cmake or meson)")
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
			buildmaster_message(COMPONENT FATAL
				"create_component '${_component}': static/shared mode requires at least one produced library spec")
		endif()
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

	_buildmaster_component_defer_arm()
	buildmaster_message(COMPONENT DEBUG "Registered component ${_component} (${_build_system}/${_library_mode})")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting create_component")
endfunction()

## @brief Declare an order-only edge (no link line).
## @param[in] source Component id or CMake target (resolved at finalize).
## @param[in] dest   Component id (→ `<dest>_install`), meta id, existing target,
##            or `<id>_install` / `<id>_configure` / `<id>_build`.
## @note A non-BUILDONLY component must not depend on a BUILDONLY component
##       (checked at materialize). BUILDONLY may depend on BUILDONLY or normal.
## @note May be called before either endpoint exists; edges are recorded and
##       resolved in `_buildmaster_finalize_components`.
function(component_dependency source dest)
	buildmaster_message(COMPONENT LOWLEVEL "Entering component_dependency")
	if(ARGC GREATER 2)
		buildmaster_message(COMPONENT FATAL
			"component_dependency: expected exactly two arguments")
	endif()
	if("${source}" STREQUAL "" OR "${dest}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL
			"component_dependency: source and dest must be non-empty")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		buildmaster_message(COMPONENT FATAL
			"component_dependency: called after finalize")
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES
		"${source}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS
		"${dest}")
	_buildmaster_component_defer_arm()
	buildmaster_message(COMPONENT DEBUG "component_dependency ${source} → ${dest}")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting component_dependency")
endfunction()

## @brief Declare a link from a component (and order when dest is a graph node).
## @param[in] source Registered component id (INTERFACE after finalize).
## @param[in] dest   Registered component or meta, library spec, existing target,
##            or archive path.
## @note Linking to a BUILDONLY component is FATAL at materialize.
## @note component_link only participates in the BuildMaster graph; host app
##       targets use target_link_libraries(… PRIVATE <component_id>).
## @note When dest is a component, meta, existing target, or stage name, an
##       order-only `component_dependency` is recorded automatically.
function(component_link source dest)
	buildmaster_message(COMPONENT LOWLEVEL "Entering component_link")
	if(ARGC GREATER 2)
		buildmaster_message(COMPONENT FATAL
			"component_link: expected exactly two arguments")
	endif()
	if("${source}" STREQUAL "" OR "${dest}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL
			"component_link: source and dest must be non-empty")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		buildmaster_message(COMPONENT FATAL
			"component_link: called after finalize")
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES
		"${source}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS
		"${dest}")

	_buildmaster_component_is_registered("${dest}" _dest_comp)
	_buildmaster_meta_is("${dest}" _dest_meta)
	if(_dest_comp
			OR _dest_meta
			OR TARGET "${dest}"
			OR dest MATCHES "^(.+)_(install|configure|build)$")
		component_dependency("${source}" "${dest}")
	endif()

	_buildmaster_component_defer_arm()
	buildmaster_message(COMPONENT DEBUG "component_link ${source} → ${dest}")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting component_link")
endfunction()

## @brief Declare a custom prerequisite target (download, unpack, codegen, …).
## @param[in] name Target name (must not already exist as a CMake target).
## @param[in] COMMAND  One or more command argv tokens.
## @param[in] COMMENT  Optional progress text (wrapped with the Component header).
## @param[in] WORKING_DIRECTORY Optional working directory.
## @param[in] SCRIPT   Optional path to a CMake -P script.
## @param[in] DEPENDS  Optional list of CMake targets this prerequisite waits on.
## @note Creates an `add_custom_target`. Other components wait on it via
##       `component_dependency(<id> <name>)`.
## @note If SCRIPT is set and COMMAND is not, COMMAND becomes
##       `${CMAKE_COMMAND} -P <SCRIPT>`.
function(component_prerequisite name)
	buildmaster_message(COMPONENT LOWLEVEL "Entering component_prerequisite")
	if("${name}" STREQUAL "")
		buildmaster_message(COMPONENT FATAL
			"component_prerequisite: empty name")
	endif()
	if(TARGET "${name}")
		buildmaster_message(COMPONENT FATAL
			"component_prerequisite: target '${name}' already exists")
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
		buildmaster_message(COMPONENT FATAL
			"component_prerequisite('${name}'): need COMMAND and/or SCRIPT")
	endif()
	if(NOT ARG_COMMENT)
		set(ARG_COMMENT "prerequisite: ${name}")
	endif()
	if(COMMAND buildmaster_log_comment)
		buildmaster_log_comment(_bm_cmt COMPONENT "${ARG_COMMENT}")
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
	buildmaster_message(COMPONENT DEBUG "prerequisite target ${name}")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting component_prerequisite")
endfunction()

# =============================================================================
# Shared helpers used by backend materialize
# =============================================================================

## @brief Whether `id` was registered with create_component.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE/FALSE.
## @note Meta ids are not included; use `_buildmaster_meta_is()`.
function(_buildmaster_component_is_registered id out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_is_registered")
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		list(FIND _ids "${id}" _idx)
		if(NOT _idx EQUAL -1)
			set(${out_var} TRUE PARENT_SCOPE)
			buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_is_registered")
			return()
		endif()
	endif()
	set(${out_var} FALSE PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_is_registered")
endfunction()

## @brief Whether a registered component is BUILDONLY.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE if the BUILDONLY flag is set, else FALSE.
## @note Unregistered ids yield FALSE (property unset).
function(_buildmaster_component_is_buildonly id out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_is_buildonly")
	get_property(_bo GLOBAL PROPERTY BUILDMASTER_COMPONENT_${id}_BUILDONLY)
	if(_bo)
		set(${out_var} TRUE PARENT_SCOPE)
	else()
		set(${out_var} FALSE PARENT_SCOPE)
	endif()
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_is_buildonly")
endfunction()

## @brief Whether this component must use build-time configure.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE if `id` appears as a dependency source.
## @note Configure-time configure is used when the component has no recorded
##       incoming edges; otherwise configure runs as a build step (dependant
##       template) so artifacts from dest can exist first.
function(_buildmaster_component_has_deferred_configure id out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_has_deferred_configure")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	if(_srcs)
		list(FIND _srcs "${id}" _idx)
		if(NOT _idx EQUAL -1)
			set(${out_var} TRUE PARENT_SCOPE)
			buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_has_deferred_configure")
			return()
		endif()
	endif()
	set(${out_var} FALSE PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_has_deferred_configure")
endfunction()

## @brief Resolve one dependency dest to a CMake target name.
## @param[in]  dest    Component id, meta id, stage name, or existing target.
## @param[out] out_tgt Resolved target (e.g. `<id>_install`).
## @param[out] out_ok  TRUE if dest resolved.
## @note Resolution order: registered component → meta → `*_install` /
##       `*_configure` / `*_build` → existing CMake target.
function(_buildmaster_resolve_dep_dest dest out_tgt out_ok)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_resolve_dep_dest")
	_buildmaster_component_is_registered("${dest}" _is_comp)
	if(_is_comp)
		set(${out_tgt} "${dest}_install" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_resolve_dep_dest")
		return()
	endif()
	_buildmaster_meta_is("${dest}" _is_meta)
	if(_is_meta)
		set(${out_tgt} "${dest}_install" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_resolve_dep_dest")
		return()
	endif()
	if(dest MATCHES "^(.+)_(install|configure|build)$")
		set(${out_tgt} "${dest}" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_resolve_dep_dest")
		return()
	endif()
	if(TARGET "${dest}")
		set(${out_tgt} "${dest}" PARENT_SCOPE)
		set(${out_ok} TRUE PARENT_SCOPE)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_resolve_dep_dest")
		return()
	endif()
	set(${out_tgt} "" PARENT_SCOPE)
	set(${out_ok} FALSE PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_resolve_dep_dest")
endfunction()

## @brief Space-separated prerequisite targets for the dependant template.
## @param[in]  id      Component whose outgoing dependency edges are collected.
## @param[out] out_var Parent-scope string of unique target names, space-joined
##            (empty if this component has no recorded dests).
## @note FATAL if dest cannot be resolved, or if a non-BUILDONLY `id` depends
##       on a BUILDONLY dest.
function(_buildmaster_component_dep_targets id out_var)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_dep_targets")
	set(_dep_targets "")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	_buildmaster_component_is_buildonly("${id}" _src_bo)

	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")
		if(NOT _src STREQUAL "${id}")
			continue()
		endif()

		_buildmaster_component_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			_buildmaster_component_is_buildonly("${_dst}" _dst_bo)
			if(_dst_bo AND NOT _src_bo)
				buildmaster_message(COMPONENT FATAL
					"component_dependency('${id}', '${_dst}'): a non-BUILDONLY component cannot depend on BUILDONLY '${_dst}' (use component_repack to publish, or make '${id}' BUILDONLY too)")
			endif()
		endif()

		_buildmaster_resolve_dep_dest("${_dst}" _tgt _ok)
		if(NOT _ok)
			buildmaster_message(COMPONENT FATAL
				"component_dependency('${id}', '${_dst}'): cannot resolve dest. Accepted: registered component id → <id>_install; meta id → <id>_install; <id>_install / _configure / _build; existing CMake target (e.g. component_prerequisite / file_* target).")
		endif()
		list(APPEND _dep_targets "${_tgt}")
	endforeach()
	if(_dep_targets)
		list(REMOVE_DUPLICATES _dep_targets)
	endif()
	string(REPLACE ";" " " _joined "${_dep_targets}")
	set(${out_var} "${_joined}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_dep_targets")
endfunction()

## @brief Fill produced names/files/dlls and install/build contract outputs.
## @param[in] _component Registered component id.
## @note Sets parent-scope: `_LIBRARY_COMPONENT_NAMES`, `_LIBRARY_COMPONENT_FILES`,
##       `_LIBRARY_COMPONENT_DLL_FILES`, `_output_libraries`, `_BM_RENAME_ENABLED`,
##       `_BM_BUILDONLY`, `_indent_level`, `_toolchain`.
## @note BUILDONLY uses the component BUILDDIR as the library root; otherwise
##       `BUILDMASTER_INSTALL_LIBDIR`. Headers mode emits a stamp path, not libs.
## @note Extra `component_link` dests that are raw library specs (not components,
##       metas, targets, or existing files) are appended to the produced lists
##       so install BYPRODUCTS stay complete.
function(_buildmaster_component_collect_outputs _component)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_collect_outputs")
	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRODUCED)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)
	get_property(_builddir GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_BUILDDIR)

	buildmaster_parse_component_options(
		_indent_level _toolchain _rename_on _buildonly _whole_ignored
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
			buildmaster_append_library_spec(
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
					_buildmaster_component_is_registered("${_ldst}" _ldst_comp)
					_buildmaster_meta_is("${_ldst}" _ldst_meta)
					if(_ldst_comp OR _ldst_meta)
						continue()
					endif()
					if(TARGET "${_ldst}")
						continue()
					endif()
					if(EXISTS "${_ldst}" AND NOT IS_DIRECTORY "${_ldst}")
						continue()
					endif()
					buildmaster_append_library_spec(
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
	set(_indent_level "${_indent_level}" PARENT_SCOPE)
	set(_toolchain "${_toolchain}" PARENT_SCOPE)
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_collect_outputs")
endfunction()

## @brief configure_file + include the shared component fragment template.
## @param[in] _component Registered component id.
## @param[in] _deferred  TRUE → dependant template (configure at build time).
## @note Collects outputs, WHOLE link items, and recorded dependencies, then
##       generates `component_<id>.cmake` under `BUILDMASTER_SCRIPTS_COMPONENTDIR`
##       and `include()`s it so IMPORTED / INTERFACE targets exist immediately.
## @note Stores produced names/files as GLOBAL properties for later link apply.
function(_buildmaster_component_write_fragment _component _deferred)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_component_write_fragment")
	# Collect in this scope: materialize locals are not visible here.
	_buildmaster_component_collect_outputs("${_component}")

	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)
	buildmaster_parse_component_options(_il _toolchain _rn _bo _wh "${_options_string}")
	if(_bo)
		set(_BM_BUILDONLY "1")
	else()
		set(_BM_BUILDONLY "0")
	endif()

	if(DEFINED BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND)
		set(ENV_CMAKE_SILENT_COMMAND ${BM_COMPONENT_ENV_CMAKE_SILENT_COMMAND})
	endif()

	set(_LIBRARY_NAME "${_component}")
	set(_LIBRARY_STAGE_INSTALL "${_component}_install")
	set(_LIBRARY_CONFIGURE_TARGET "${_component}_configure")
	set(_LIBRARY_BUILD_TARGET "${_component}_build")

	_buildmaster_component_dep_targets("${_component}" _LIBRARY_DEPENDENCIES)

	if(NOT _toolchain STREQUAL "")
		set(_LIBRARY_TOOLCHAIN_SUFFIX " (with toolchain ${_toolchain})")
	else()
		set(_LIBRARY_TOOLCHAIN_SUFFIX "")
	endif()

	# WHOLE → one closed whole-archive region for all produced static paths
	set(_BM_WHOLE "0")
	set(_BM_WHOLE_LINK_ITEMS "")
	get_property(_whole_prop GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_WHOLE)
	if(_whole_prop)
		if(NOT _library_mode STREQUAL "static")
			buildmaster_message(COMPONENT WARNING
				"WHOLE ignored for '${_component}' (mode '${_library_mode}'; only static is supported)")
		elseif(_LIBRARY_COMPONENT_FILES)
			set(_BM_WHOLE "1")
			_buildmaster_whole_archive_link_items(_whole_list
				${_LIBRARY_COMPONENT_FILES})
			string(REPLACE ";" " " _BM_WHOLE_LINK_ITEMS "${_whole_list}")
		endif()
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

	sanitize_for_filename(_safe "${_component}")
	set(_LIBRARY_CREATE_FILE
		"${BUILDMASTER_SCRIPTS_COMPONENTDIR}/component_${_safe}.cmake")

	configure_file(
		"${BUILDMASTER_COMPONENT_TEMPLATEDIR}/${_tpl}"
		"${_LIBRARY_CREATE_FILE}"
		@ONLY
	)
	include("${_LIBRARY_CREATE_FILE}")

	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_NAMES
		"${_LIBRARY_COMPONENT_NAMES}")
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_FILES
		"${_LIBRARY_COMPONENT_FILES}")
	buildmaster_message(COMPONENT DEBUG "Wrote fragment ${_LIBRARY_CREATE_FILE} (${_tpl})")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_component_write_fragment")
endfunction()

## @brief Apply recorded component_link edges after all fragments are included.
## @note Walks `BUILDMASTER_COMPONENT_LINK_SOURCES` / `_DESTS` in lockstep.
## @note Dest kinds: meta INTERFACE, registered component (WHOLE vs produced
##       IMPORTED names), existing CMake target, existing archive file, or a
##       library spec that creates an IMPORTED target under the install libdir.
## @note FATAL if source is not a target or dest is BUILDONLY.
function(_buildmaster_apply_links)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_apply_links")
	get_property(_lsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
	if(NOT _lsrcs)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_apply_links")
		return()
	endif()
	set(_i 0)
	foreach(_src IN LISTS _lsrcs)
		list(GET _ldsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")

		if(NOT TARGET "${_src}")
			buildmaster_message(COMPONENT FATAL
				"component_link: source '${_src}' is not a target (missing create_*_component?)")
		endif()

		_buildmaster_meta_is("${_dst}" _dst_meta)
		if(_dst_meta)
			if(TARGET "${_dst}")
				target_link_libraries(${_src} INTERFACE ${_dst})
			endif()
			continue()
		endif()

		_buildmaster_component_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			_buildmaster_component_is_buildonly("${_dst}" _dst_bo)
			if(_dst_bo)
				buildmaster_message(COMPONENT FATAL
					"component_link: cannot link to BUILDONLY component '${_dst}' (order only via component_dependency between BUILDONLY phases, or component_repack to publish)")
			endif()
			# WHOLE dest: INTERFACE already carries whole-archive items; do not
			# also link plain IMPORTED names (would drop whole or double-link).
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

		get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_src}_MODE)
		if(_mode STREQUAL "" OR _mode STREQUAL "headers")
			set(_mode "static")
		endif()
		set(_n "")
		set(_f "")
		set(_d "")
		buildmaster_parse_subcomponent("${_dst}" _t _n0 _s)
		buildmaster_append_library_spec(
			"${_mode}" "${_dst}" "${BUILDMASTER_INSTALL_LIBDIR}" _n _f _d)
		list(GET _n 0 _tn)
		list(GET _f 0 _tf)
		if(NOT TARGET "${_tn}")
			if(_mode STREQUAL "shared")
				add_library(${_tn} SHARED IMPORTED GLOBAL)
			else()
				add_library(${_tn} STATIC IMPORTED GLOBAL)
			endif()
			set_target_properties(${_tn} PROPERTIES
				IMPORTED_LOCATION "${_tf}"
				IMPORTED_LOCATION_DEBUG "${_tf}"
				IMPORTED_LOCATION_RELEASE "${_tf}"
				IMPORTED_LOCATION_MINSIZEREL "${_tf}"
				IMPORTED_LOCATION_RELWITHDEBINFO "${_tf}"
			)
		endif()
		target_link_libraries(${_src} INTERFACE ${_tn})
	endforeach()
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_apply_links")
endfunction()

## @brief Deferred materialize: metas, components, repacks, links, orphan warn.
## @note Idempotent. Scheduled by `_buildmaster_component_defer_arm`; not public.
##       Harness may call this before configure-time contract checks.
##       Metas are created first so component_link/dependency can resolve them;
##       their INTERFACE is wired after real components exist.
## @note Order: materialize metas → per-id cmake/meson materialize → repacks →
##       meta wire → apply links → orphan warning.
function(_buildmaster_finalize_components)
	buildmaster_message(COMPONENT LOWLEVEL "Entering _buildmaster_finalize_components")
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_finalize_components")
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED TRUE)

	_buildmaster_materialize_metas()

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		foreach(_id IN LISTS _ids)
			get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM)
			if(_sys STREQUAL "cmake")
				_buildmaster_materialize_cmake("${_id}")
			elseif(_sys STREQUAL "meson")
				_buildmaster_materialize_meson("${_id}")
			else()
				buildmaster_message(COMPONENT FATAL
					"finalize: unknown system '${_sys}' for '${_id}'")
			endif()
		endforeach()
	endif()

	_buildmaster_materialize_repacks()
	_buildmaster_meta_wire()
	_buildmaster_apply_links()
	_buildmaster_warn_orphans()
	buildmaster_message(COMPONENT DEBUG "Component graph finalized")
	buildmaster_message(COMPONENT LOWLEVEL "Exiting _buildmaster_finalize_components")
endfunction()

include("${CMAKE_CURRENT_LIST_DIR}/meta.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/repack.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/cmake/helpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/meson/helpers.cmake")
