# =============================================================================
# component/helpers.cmake — registry, graph, shared fragment emit
# =============================================================================
# Public: create_component, component_dependency, component_link.
# Backends (component/cmake, component/meson) own create_*_stages and
# _buildmaster_materialize_{cmake,meson}.
# Nested bootstrap that only include()s this file still loads the wrappers.

## @brief Keys that may appear without '=' (flag form → enabled).
set(BUILDMASTER_COMPONENT_OPTION_FLAGS "RENAME")

## @brief Split one options token into key and value.
## @param[in]  pair     Raw token (KEY=value, KEY=, or KEY for flags).
## @param[out] out_key  Uppercase stripped key (parent scope).
## @param[out] out_val  Value (may be empty).
## @param[out] out_ok   TRUE if the token is usable.
## @note Tokens without '=' are only accepted when the key is listed in
##       BUILDMASTER_COMPONENT_OPTION_FLAGS (e.g. RENAME ≡ RENAME=ON).
function(buildmaster_option_pair_split pair out_key out_val out_ok)
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
				message(WARNING
					"[BuildMaster] Option '${pair}' requires KEY=value form (ignored)")
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
endfunction()

## @brief Interpret a flag option value.
## @param[in]  val      Empty (flag form), or ON/OFF-style string.
## @param[out] out_bool Parent-scope TRUE/FALSE.
## @note Empty value means enabled (RENAME ≡ RENAME=ON ≡ RENAME=).
function(buildmaster_option_flag_enabled val out_bool)
	if("${val}" STREQUAL "")
		set(${out_bool} TRUE PARENT_SCOPE)
		return()
	endif()
	string(TOUPPER "${val}" _v)
	if(_v STREQUAL "1" OR _v STREQUAL "ON" OR _v STREQUAL "TRUE" OR _v STREQUAL "YES")
		set(${out_bool} TRUE PARENT_SCOPE)
	elseif(_v STREQUAL "0" OR _v STREQUAL "OFF" OR _v STREQUAL "FALSE" OR _v STREQUAL "NO")
		set(${out_bool} FALSE PARENT_SCOPE)
	else()
		message(WARNING
			"[BuildMaster] Unrecognized flag value '${val}' (treated as OFF)")
		set(${out_bool} FALSE PARENT_SCOPE)
	endif()
endfunction()

## @brief Parse the optional KEY=VALUE;… options string used by create_*_component.
## @param[out] out_indent     Indent level (integer, default 0).
## @param[out] out_toolchain  Toolchain name (empty = inherit).
## @param[out] out_rename     TRUE/FALSE — normalize variant installs (default TRUE).
## @param[in]  options_string Optional "KEY=value;KEY2=…" string.
## @note Flag keys listed in BUILDMASTER_COMPONENT_OPTION_FLAGS may omit '='.
##       Unknown keys → WARNING. LINK_EXTRA is removed; use component_link().
function(buildmaster_parse_component_options out_indent out_toolchain out_rename options_string)
	set(_indent 0)
	set(_toolchain "")
	set(_rename TRUE)

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
					message(WARNING
						"[BuildMaster] INDENT must be a non-negative integer, got '${_val}'")
				endif()
			elseif(_key STREQUAL "TOOLCHAIN")
				set(_toolchain "${_val}")
			elseif(_key STREQUAL "LINK_EXTRA")
				message(WARNING
					"[BuildMaster] LINK_EXTRA is removed; use component_link() (ignored)")
			elseif(_key STREQUAL "RENAME")
				buildmaster_option_flag_enabled("${_val}" _rename)
			else()
				message(WARNING
					"[BuildMaster] Unknown component option '${_key}' (ignored)")
			endif()
		endforeach()
	endif()

	set(${out_indent} "${_indent}" PARENT_SCOPE)
	set(${out_toolchain} "${_toolchain}" PARENT_SCOPE)
	set(${out_rename} "${_rename}" PARENT_SCOPE)
endfunction()

## @brief Split a library spec into CMake target, library basename and libdir subdir.
## @param[in]  spec        Either `<name>` or `<subdir>/<name>`.
## @param[out] out_target  Imported CMake target name (`/` → `_`).
## @param[out] out_libname Library basename without prefix/suffix.
## @param[out] out_subdir  Directory relative to BUILDMASTER_INSTALL_LIBDIR, or empty.
function(buildmaster_parse_subcomponent spec out_target out_libname out_subdir)
	if("${spec}" STREQUAL "")
		message(FATAL_ERROR
			"[BuildMaster] buildmaster_parse_subcomponent: empty library spec")
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
		message(FATAL_ERROR
			"[BuildMaster] buildmaster_parse_subcomponent: missing library name in '${spec}'")
	endif()

	set(${out_target} "${_tgt}" PARENT_SCOPE)
	set(${out_libname} "${_name}" PARENT_SCOPE)
	set(${out_subdir} "${_dir}" PARENT_SCOPE)
endfunction()

## @brief Resolve one library spec into IMPORTED name + file path (+ MSVC DLL).
## @param[in]  library_mode `static` or `shared`.
## @param[in]  spec         Library spec (`<name>` or `<subdir>/<name>`).
## @param[out] names_var    List variable receiving the imported target name.
## @param[out] files_var    List variable receiving the archive/import path.
## @param[out] dlls_var     List variable receiving the MSVC DLL path (shared only).
macro(buildmaster_append_library_spec library_mode spec names_var files_var dlls_var)
	buildmaster_parse_subcomponent("${spec}" _bm_as_tgt _bm_as_name _bm_as_subdir)
	list(APPEND ${names_var} "${_bm_as_tgt}")
	if("${library_mode}" STREQUAL "static")
		library_import_static_hint(_bm_as_path "${_bm_as_name}"
			"${BUILDMASTER_INSTALL_LIBDIR}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
	else()
		library_import_hint(_bm_as_path "${_bm_as_name}"
			"${BUILDMASTER_INSTALL_LIBDIR}" "${_bm_as_subdir}")
		list(APPEND ${files_var} "${_bm_as_path}")
		if(MSVC)
			list(APPEND ${dlls_var}
				"${BUILDMASTER_INSTALL_BINDIR}/${_bm_as_name}${CMAKE_SHARED_LIBRARY_SUFFIX}")
		endif()
	endif()
endmacro()

# =============================================================================
# Registry and declarative graph
# =============================================================================

## @brief Schedule deferred component materialization once per configure.
## @note Uses cmake_language(DEFER) on CMAKE_SOURCE_DIR so all create_* and
##       component_dependency/link calls in the tree are seen first.
##       Requires CMake >= 3.19.
function(_buildmaster_component_defer_arm)
	get_property(_armed GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEFER_ARMED)
	if(_armed)
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEFER_ARMED TRUE)
	cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
		CALL _buildmaster_finalize_components)
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
##            Empty for headers mode.
## @param[in] options_string Optional trailing "KEY=value;…" string.
##            Keys: INDENT / INDENT_LEVEL, TOOLCHAIN, RENAME (flag).
## @note Does not return a fragment path and does not include() anything.
##       Prefer create_cmake_* / create_meson_* wrappers.
## @note create_*_stages is internal; backends call it from materialize only.
function(create_component _component _component_title _srcdir _builddir
						_options _library_mode _build_system _produced)
	if(ARGC GREATER 9)
		message(FATAL_ERROR
			"[BuildMaster] create_component: too many arguments "
			"(expected at most one options string).")
	endif()

	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		message(FATAL_ERROR
			"[BuildMaster] create_component('${_component}'): "
			"called after components were finalized")
	endif()

	if("${_component}" STREQUAL "")
		message(FATAL_ERROR "[BuildMaster] create_component: empty component id")
	endif()

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		list(FIND _ids "${_component}" _idx)
		if(NOT _idx EQUAL -1)
			message(FATAL_ERROR
				"[BuildMaster] create_component: duplicate id '${_component}'")
		endif()
	endif()

	set(_options_string "")
	if(ARGC GREATER 8)
		set(_options_string "${ARGV8}")
	endif()

	string(TOLOWER "${_library_mode}" _library_mode)
	string(TOLOWER "${_build_system}" _build_system)

	if(NOT _library_mode STREQUAL "static"
			AND NOT _library_mode STREQUAL "shared"
			AND NOT _library_mode STREQUAL "headers")
		message(FATAL_ERROR
			"[BuildMaster] create_component: unknown library mode '${_library_mode}' "
			"(expected static, shared, or headers)")
	endif()

	if(NOT _build_system STREQUAL "cmake" AND NOT _build_system STREQUAL "meson")
		message(FATAL_ERROR
			"[BuildMaster] create_component: unknown build system '${_build_system}' "
			"(expected cmake or meson)")
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
			message(FATAL_ERROR
				"[BuildMaster] create_component '${_component}': "
				"static/shared mode requires at least one produced library spec")
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

	_buildmaster_component_defer_arm()
endfunction()

## @brief Declare an order-only edge (no link line).
## @param[in] source Component id or CMake target (resolved at finalize).
##            For a registered component, deferred configure hangs off
##            `<source>_configure`.
## @param[in] dest   Component id (→ `<dest>_install`), existing target, or
##            `<id>_install` / `<id>_configure` / `<id>_build`.
## @note May be called before either end is registered. Any dependency on
##       another install/target selects build-time configure (old dependant).
function(component_dependency source dest)
	if(ARGC GREATER 2)
		message(FATAL_ERROR
			"[BuildMaster] component_dependency: expected exactly two arguments")
	endif()
	if("${source}" STREQUAL "" OR "${dest}" STREQUAL "")
		message(FATAL_ERROR
			"[BuildMaster] component_dependency: source and dest must be non-empty")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		message(FATAL_ERROR
			"[BuildMaster] component_dependency: called after finalize")
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES
		"${source}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS
		"${dest}")
	_buildmaster_component_defer_arm()
endfunction()

## @brief Declare a link from a component plus an order edge.
## @param[in] source Registered component id (INTERFACE after finalize).
## @param[in] dest   Registered component (all produced libs), library spec
##            `<name>` or `<subdir>/<name>`, existing target, or archive path.
## @note Also records component_dependency(source, dest) so install or custom
##       prerequisites run first.
function(component_link source dest)
	if(ARGC GREATER 2)
		message(FATAL_ERROR
			"[BuildMaster] component_link: expected exactly two arguments")
	endif()
	if("${source}" STREQUAL "" OR "${dest}" STREQUAL "")
		message(FATAL_ERROR
			"[BuildMaster] component_link: source and dest must be non-empty")
	endif()
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		message(FATAL_ERROR
			"[BuildMaster] component_link: called after finalize")
	endif()
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES
		"${source}")
	set_property(GLOBAL APPEND PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS
		"${dest}")
	component_dependency("${source}" "${dest}")
endfunction()

# =============================================================================
# Shared helpers used by backend materialize
# =============================================================================

## @brief Whether `id` was registered with create_component.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE or FALSE.
function(_buildmaster_component_is_registered id out_var)
	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(_ids)
		list(FIND _ids "${id}" _idx)
		if(NOT _idx EQUAL -1)
			set(${out_var} TRUE PARENT_SCOPE)
			return()
		endif()
	endif()
	set(${out_var} FALSE PARENT_SCOPE)
endfunction()

## @brief Whether this component must use build-time configure.
## @param[in]  id      Component identifier.
## @param[out] out_var Parent-scope TRUE if any component_dependency lists id
##            as source (same behaviour as the old dependant templates).
function(_buildmaster_component_has_deferred_configure id out_var)
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")
		if(_src STREQUAL "${id}")
			set(${out_var} TRUE PARENT_SCOPE)
			return()
		endif()
	endforeach()
	set(${out_var} FALSE PARENT_SCOPE)
endfunction()

## @brief Space-separated prerequisite targets for the dependant template.
## @param[in]  id      Component identifier (dependency source).
## @param[out] out_var Parent-scope string for @_LIBRARY_DEPENDENCIES@.
## @note Registered dest → `<dest>_install`. Explicit stage names and existing
##       CMake targets are kept as-is when already resolvable.
function(_buildmaster_component_dep_targets id out_var)
	set(_dep_targets "")
	get_property(_srcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_SOURCES)
	get_property(_dsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_DEP_DESTS)
	set(_i 0)
	foreach(_src IN LISTS _srcs)
		list(GET _dsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")
		if(NOT _src STREQUAL "${id}")
			continue()
		endif()
		_buildmaster_component_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			list(APPEND _dep_targets "${_dst}_install")
		elseif(_dst MATCHES "^(.+)_(install|configure|build)$")
			list(APPEND _dep_targets "${_dst}")
		elseif(TARGET "${_dst}")
			list(APPEND _dep_targets "${_dst}")
		endif()
	endforeach()
	if(_dep_targets)
		list(REMOVE_DUPLICATES _dep_targets)
	endif()
	string(REPLACE ";" " " _joined "${_dep_targets}")
	set(${out_var} "${_joined}" PARENT_SCOPE)
endfunction()

## @brief Fill produced names/files/dlls and install-contract outputs.
## @param[in] _component Component identifier.
## @note Sets parent-scope: `_LIBRARY_COMPONENT_NAMES`, `_LIBRARY_COMPONENT_FILES`,
##       `_LIBRARY_COMPONENT_DLL_FILES`, `_output_libraries`, `_BM_RENAME_ENABLED`,
##       `_indent_level`, `_toolchain`.
## @note Also appends library specs from `component_link(<this>, <spec>)` so those
##       archives are install OUTPUTs (Ninja needs a rule; same role as the old
##       LINK_EXTRA list). Registered components, existing targets, and plain
##       filesystem paths are skipped here.
function(_buildmaster_component_collect_outputs _component)
	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_PRODUCED)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)

	buildmaster_parse_component_options(
		_indent_level _toolchain _rename_on "${_options_string}")

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
		set(_headers_stamp
			"${BUILDMASTER_INSTALL_INCLUDEDIR}/.bm_${_component}_headers.stamp")
		set(_output_libraries "${_headers_stamp}")
	else()
		foreach(_spec IN LISTS _produced)
			if(_spec STREQUAL "")
				continue()
			endif()
			buildmaster_append_library_spec(
				"${_library_mode}" "${_spec}"
				_LIBRARY_COMPONENT_NAMES _LIBRARY_COMPONENT_FILES
				_LIBRARY_COMPONENT_DLL_FILES)
		endforeach()

		# Library specs from component_link(source, spec) must be install OUTPUTs
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
				if(_ldst_comp)
					continue()
				endif()
				if(TARGET "${_ldst}")
					continue()
				endif()
				if(EXISTS "${_ldst}" AND NOT IS_DIRECTORY "${_ldst}")
					continue()
				endif()
				buildmaster_append_library_spec(
					"${_library_mode}" "${_ldst}"
					_LIBRARY_COMPONENT_NAMES _LIBRARY_COMPONENT_FILES
					_LIBRARY_COMPONENT_DLL_FILES)
			endforeach()
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
	set(_indent_level "${_indent_level}" PARENT_SCOPE)
	set(_toolchain "${_toolchain}" PARENT_SCOPE)
endfunction()

## @brief configure_file + include the shared component fragment template.
## @param[in] _component Component identifier.
## @param[in] _deferred  TRUE → use `*_dependant.cmake.in` templates.
## @note Caller must set `_LIBRARY_CONFIGURE_FILE`, `_LIBRARY_BUILD_FILE`,
##       `_LIBRARY_INSTALL_FILE`, and `_LIBRARY_COMPONENT_*` in the current
##       scope (typically after create_*_stages and collect_outputs).
function(_buildmaster_component_write_fragment _component _deferred)
	get_property(_library_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_MODE)
	get_property(_options_string GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_component}_OPTSTR)
	buildmaster_parse_component_options(_il _toolchain _rn "${_options_string}")

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
endfunction()

## @brief Apply recorded component_link edges after all fragments are included.
## @note Resolves dest as: registered component (produced IMPORTED targets +
##       INTERFACE), existing CMake target, existing archive path, or library
##       spec under BUILDMASTER_INSTALL_LIBDIR.
function(_buildmaster_apply_links)
	get_property(_lsrcs GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_SOURCES)
	get_property(_ldsts GLOBAL PROPERTY BUILDMASTER_COMPONENT_LINK_DESTS)
	if(NOT _lsrcs)
		return()
	endif()
	set(_i 0)
	foreach(_src IN LISTS _lsrcs)
		list(GET _ldsts ${_i} _dst)
		math(EXPR _i "${_i} + 1")

		if(NOT TARGET "${_src}")
			message(FATAL_ERROR
				"[BuildMaster] component_link: source '${_src}' is not a target "
				"(missing create_component?)")
		endif()

		_buildmaster_component_is_registered("${_dst}" _dst_comp)
		if(_dst_comp)
			get_property(_names GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_dst}_NAMES)
			foreach(_lib IN LISTS _names)
				if(TARGET "${_lib}")
					target_link_libraries(${_src} INTERFACE ${_lib})
				endif()
			endforeach()
			if(TARGET "${_dst}")
				target_link_libraries(${_src} INTERFACE ${_dst})
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
		buildmaster_append_library_spec("${_mode}" "${_dst}" _n _f _d)
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
endfunction()

## @brief Deferred materialize: dispatch per backend, then apply links.
## @note Idempotent. Scheduled by _buildmaster_component_defer_arm; not public.
function(_buildmaster_finalize_components)
	get_property(_done GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED)
	if(_done)
		return()
	endif()
	set_property(GLOBAL PROPERTY BUILDMASTER_COMPONENTS_FINALIZED TRUE)

	get_property(_ids GLOBAL PROPERTY BUILDMASTER_COMPONENT_IDS)
	if(NOT _ids)
		return()
	endif()

	foreach(_id IN LISTS _ids)
		get_property(_sys GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_SYSTEM)
		if(_sys STREQUAL "cmake")
			_buildmaster_materialize_cmake("${_id}")
		elseif(_sys STREQUAL "meson")
			_buildmaster_materialize_meson("${_id}")
		else()
			message(FATAL_ERROR
				"[BuildMaster] finalize: unknown system '${_sys}' for '${_id}'")
		endif()
	endforeach()

	_buildmaster_apply_links()
endfunction()

include("${CMAKE_CURRENT_LIST_DIR}/cmake/helpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/meson/helpers.cmake")
