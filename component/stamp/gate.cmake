# =============================================================================
# component/stamp/gate.cmake — stage early-out from a tree digest
# =============================================================================
# CMake only: file(SHA256), string(SHA256), file(LOCK). No sha256sum, no cat,
# no shell. Git runs only when this leaf already has GIT={PATCH}.
#
# bm-stamp.key (builddir), written after a successful install:
#   tree=<sha256>
#   extra=<sha256>
# bm-stamp.extra is the non-tree half in the clear (options, toolchain,
# build type, IPO, mode, produced, OS/arch). A later install cache reads
# these two files; it is not implemented here.
#
# The tree digest is taken AFTER patches, before configure/build. A later
# make may apply again and hash again. A hit skips the nested tool and
# resets when this process is the last live holder of that git root.

## @brief Remember absolute patch paths for one git root.
## @param[in] _root    Git work tree.
## @param[in] _patches List of patch files (relative paths allowed).
## @note Rewrites `stamp_patches_<sha1>.txt` from the in-process union so a
##       reconfigure does not append a second copy of the same path.
function(_bm_stamp_note_patches _root _patches)
	if("${_root}" STREQUAL "" OR "${_patches}" STREQUAL "")
		return()
	endif()
	if(NOT DEFINED BUILDMASTER_SCRIPTS_GIT_DIR OR "${BUILDMASTER_SCRIPTS_GIT_DIR}" STREQUAL "")
		return()
	endif()
	string(SHA1 _rhash "${_root}")
	get_property(_have GLOBAL PROPERTY _BM_STAMP_PATCHES_${_rhash})
	set(_all "")
	if(_have)
		set(_all "${_have}")
	endif()
	foreach(_p IN LISTS _patches)
		if(_p STREQUAL "")
			continue()
		endif()
		get_filename_component(_abs "${_p}" ABSOLUTE)
		list(APPEND _all "${_abs}")
	endforeach()
	if(_all STREQUAL "")
		return()
	endif()
	list(REMOVE_DUPLICATES _all)
	set_property(GLOBAL PROPERTY _BM_STAMP_PATCHES_${_rhash} "${_all}")
	file(MAKE_DIRECTORY "${BUILDMASTER_SCRIPTS_GIT_DIR}")
	set(_man "${BUILDMASTER_SCRIPTS_GIT_DIR}/stamp_patches_${_rhash}.txt")
	file(WRITE "${_man}" "")
	foreach(_p IN LISTS _all)
		file(APPEND "${_man}" "${_p}\n")
	endforeach()
endfunction()

## @brief Write the git argv the stage script will include.
## @param[in] _path Destination cmake file.
function(_bm_stamp_write_env _path)
	if(NOT DEFINED ENV_GIT_SILENT_COMMAND OR "${ENV_GIT_SILENT_COMMAND}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"stamp: GIT PATCH needs the git runner (ENV_GIT_SILENT_COMMAND)")
	endif()
	set(_line "set(BM_STAMP_GIT")
	foreach(_tok IN LISTS ENV_GIT_SILENT_COMMAND)
		string(REPLACE "\\" "\\\\" _tok "${_tok}")
		string(REPLACE "\"" "\\\"" _tok "${_tok}")
		string(APPEND _line " \"${_tok}\"")
	endforeach()
	string(APPEND _line ")")
	file(WRITE "${_path}" "${_line}\n")
endfunction()

## @brief Bake the non-tree half of the stamp into the stage scripts.
## @param[in] _id      Component id.
## @param[in] _srcdir  Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _ipo_on  `BM_TC_IPO_ON` at stage generation.
## @param[in] _ipo_fat `BM_TC_IPO_FAT` at stage generation.
## @param[in] _tc      Toolchain profile name (may be empty).
## @note Sets `_BM_STAMP_*` in the caller. Those names are substituted into
##       the cmake and meson stage templates.
function(_bm_stamp_bake _id _srcdir _builddir _ipo_on _ipo_fat _tc)
	get_property(_optstr GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_OPTSTR)
	get_property(_options GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_OPTIONS)
	get_property(_mode GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_MODE)
	get_property(_produced GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_PRODUCED)
	get_property(_noinstall GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_NOINSTALL)
	get_property(_wd GLOBAL PROPERTY BUILDMASTER_COMPONENT_${_id}_GIT_WORKDIR)
	if(NOT DEFINED CMAKE_BUILD_TYPE)
		set(CMAKE_BUILD_TYPE "")
	endif()
	set(_text
"build_type=${CMAKE_BUILD_TYPE}
system=${CMAKE_SYSTEM_NAME}
arch=${CMAKE_SYSTEM_PROCESSOR}
compiler=${CMAKE_C_COMPILER}
ipo=${_ipo_on}
ipo_fat=${_ipo_fat}
toolchain=${_tc}
mode=${_mode}
produced=${_produced}
noinstall=${_noinstall}
optstr=${_optstr}
options=${_options}
")
	string(SHA256 _extra "${_text}")
	file(MAKE_DIRECTORY "${_builddir}")
	file(WRITE "${_builddir}/bm-stamp.extra" "${_text}")

	set(_patches "")
	set(_holders "")
	set(_env "")
	if(NOT "${_wd}" STREQUAL "")
		string(SHA1 _rhash "${_wd}")
		set(_man "${BUILDMASTER_SCRIPTS_GIT_DIR}/stamp_patches_${_rhash}.txt")
		if(EXISTS "${_man}")
			set(_patches "${_man}")
			set(_holders "${BUILDMASTER_SCRIPTS_GIT_DIR}/stamp_holders_${_rhash}")
			set(_env "${BUILDMASTER_SCRIPTS_GIT_DIR}/stamp_git_${_rhash}.cmake")
			_bm_stamp_write_env("${_env}")
		endif()
	endif()

	set(_BM_STAMP_ID "${_id}" PARENT_SCOPE)
	set(_BM_STAMP_SRCDIR "${_srcdir}" PARENT_SCOPE)
	set(_BM_STAMP_BUILDDIR "${_builddir}" PARENT_SCOPE)
	set(_BM_STAMP_EXTRA "${_extra}" PARENT_SCOPE)
	set(_BM_STAMP_WORKDIR "${_wd}" PARENT_SCOPE)
	set(_BM_STAMP_PATCHES "${_patches}" PARENT_SCOPE)
	set(_BM_STAMP_HOLDERS "${_holders}" PARENT_SCOPE)
	set(_BM_STAMP_ENV "${_env}" PARENT_SCOPE)
endfunction()

## @brief SHA256 of every file under `_root` except `.git` and `_builddir`.
## @param[in]  _root     Directory to hash (the component srcdir).
## @param[in]  _builddir Build directory to skip when it sits inside `_root`.
## @param[out] _out      Hex digest in the caller.
## @note One `file(SHA256)` per file, then `string(SHA256)` of the sorted
##       `relative-path digest` lines. That is the concatenation digest
##       without reading every byte into one string.
function(_bm_stamp_tree_sha _root _builddir _out)
	set_property(GLOBAL PROPERTY _BM_STAMP_ACC "")
	file(TO_CMAKE_PATH "${_root}" _rootn)
	set(_bn "")
	if(NOT "${_builddir}" STREQUAL "")
		file(TO_CMAKE_PATH "${_builddir}" _bn)
	endif()
	_bm_stamp_walk("${_rootn}" "${_rootn}" "${_bn}")
	get_property(_acc GLOBAL PROPERTY _BM_STAMP_ACC)
	set_property(GLOBAL PROPERTY _BM_STAMP_ACC "")
	string(STRIP "${_acc}" _acc)
	if(_acc STREQUAL "")
		set(_blob "")
	else()
		string(REPLACE "\n" ";" _lines "${_acc}")
		list(SORT _lines)
		list(JOIN _lines "\n" _blob)
	endif()
	string(SHA256 _sum "${_blob}")
	set(${_out} "${_sum}" PARENT_SCOPE)
endfunction()

## @brief Recurse `_dir` and append `relpath file-sha256` lines.
## @param[in] _dir   Directory to list.
## @param[in] _root  Hash root (relative paths start here).
## @param[in] _builddir Normalized build dir, or empty. Skipped when it is
##            a real subdirectory of `_root`.
function(_bm_stamp_walk _dir _root _builddir)
	file(GLOB _entries LIST_DIRECTORIES true "${_dir}/*" "${_dir}/.*")
	foreach(_e IN LISTS _entries)
		get_filename_component(_name "${_e}" NAME)
		if(_name STREQUAL "." OR _name STREQUAL "..")
			continue()
		endif()
		if(_name STREQUAL ".git")
			continue()
		endif()
		file(TO_CMAKE_PATH "${_e}" _en)
		if(NOT "${_builddir}" STREQUAL ""
				AND NOT "${_builddir}" STREQUAL "${_root}"
				AND "${_en}" STREQUAL "${_builddir}")
			continue()
		endif()
		if(IS_DIRECTORY "${_e}" AND NOT IS_SYMLINK "${_e}")
			_bm_stamp_walk("${_en}" "${_root}" "${_builddir}")
		elseif(NOT IS_DIRECTORY "${_e}")
			file(RELATIVE_PATH _rel "${_root}" "${_en}")
			string(REPLACE "\\" "/" _rel "${_rel}")
			file(SHA256 "${_en}" _h)
			get_property(_acc GLOBAL PROPERTY _BM_STAMP_ACC)
			string(APPEND _acc "${_rel} ${_h}\n")
			set_property(GLOBAL PROPERTY _BM_STAMP_ACC "${_acc}")
		endif()
	endforeach()
endfunction()

## @brief `git reset --hard` and `git clean -fd` in `_repo`.
## @param[in] _repo Work tree.
function(_bm_stamp_git_reset _repo)
	if("${BM_STAMP_GIT}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL
			"stamp: git command is empty; cannot reset ${_repo}")
	endif()
	execute_process(
		COMMAND ${BM_STAMP_GIT} -C "${_repo}" reset --hard
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		_bm_log_message(COMPONENT FATAL
			"stamp: git reset --hard failed in ${_repo} (${_rc})\n${_out}\n${_err}")
	endif()
	execute_process(
		COMMAND ${BM_STAMP_GIT} -C "${_repo}" clean -fd
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		_bm_log_message(COMPONENT FATAL
			"stamp: git clean -fd failed in ${_repo} (${_rc})\n${_out}\n${_err}")
	endif()
endfunction()

## @brief `git apply` one patch file. Failure is FATAL.
## @param[in] _repo  Work tree.
## @param[in] _patch Absolute patch path.
function(_bm_stamp_git_apply _repo _patch)
	execute_process(
		COMMAND ${BM_STAMP_GIT} -C "${_repo}" apply "${_patch}"
		RESULT_VARIABLE _rc
		OUTPUT_VARIABLE _out
		ERROR_VARIABLE _err
	)
	if(NOT _rc EQUAL 0)
		_bm_log_message(COMPONENT FATAL
			"stamp: git apply failed for ${_patch} in ${_repo} (${_rc})\n${_out}\n${_err}")
	endif()
endfunction()

## @brief Drop holder tokens whose process lock is free, then count the rest.
## @param[in]  _holders Directory of token files.
## @param[out] _out     Live token count.
## @note Caller holds `_holders.lock`.
function(_bm_stamp_reap_count _holders _out)
	file(GLOB _tokens LIST_DIRECTORIES false "${_holders}/*")
	foreach(_t IN LISTS _tokens)
		if(NOT EXISTS "${_t}")
			continue()
		endif()
		file(LOCK "${_t}" TIMEOUT 0 RESULT_VARIABLE _lk)
		if(_lk EQUAL 0)
			file(LOCK "${_t}" RELEASE)
			file(REMOVE "${_t}")
		endif()
	endforeach()
	file(GLOB _tokens LIST_DIRECTORIES false "${_holders}/*")
	list(LENGTH _tokens _n)
	set(${_out} "${_n}" PARENT_SCOPE)
endfunction()

## @brief Apply every patch in the manifest. Tree must already be clean.
## @param[in] _repo     Work tree.
## @param[in] _patches  Manifest path (one absolute patch per line).
function(_bm_stamp_apply_manifest _repo _patches)
	file(STRINGS "${_patches}" _plist)
	foreach(_p IN LISTS _plist)
		if(_p STREQUAL "")
			continue()
		endif()
		_bm_stamp_git_apply("${_repo}" "${_p}")
	endforeach()
endfunction()

## @brief Load `BM_STAMP_GIT` from the baked env file.
## @param[in] _env Path written by `_bm_stamp_write_env`.
function(_bm_stamp_load_git _env)
	if("${_env}" STREQUAL "" OR NOT EXISTS "${_env}")
		_bm_log_message(COMPONENT FATAL "stamp: missing git runner file")
	endif()
	include("${_env}")
	set(BM_STAMP_GIT "${BM_STAMP_GIT}" PARENT_SCOPE)
	if("${BM_STAMP_GIT}" STREQUAL "")
		_bm_log_message(COMPONENT FATAL "stamp: git command is empty")
	endif()
endfunction()

## @brief Decide whether this stage re-enters the nested tool.
## @param[in] _id       Component id.
## @param[in] _stage    `configure`, `build`, or `install`.
## @param[in] _srcdir   Component source directory.
## @param[in] _builddir Component build directory.
## @param[in] _extra    Hex digest of the non-tree key.
## @param[in] _workdir  Git work tree, or empty.
## @param[in] _patches  Patch manifest, or empty when this leaf has no PATCH.
## @param[in] _holders  Holder directory for that git root, or empty.
## @param[in] _env      Git argv file, or empty.
## @note Sets `BM_STAMP_SKIP` in the caller. On a hit the nested cmake/meson
##       must not run. On a miss the tree is patched until `_bm_stamp_leave`.
function(_bm_stamp_enter _id _stage _srcdir _builddir _extra _workdir _patches _holders _env)
	set(BM_STAMP_SKIP FALSE PARENT_SCOPE)
	set(BM_STAMP_HOLD FALSE PARENT_SCOPE)
	set(BM_STAMP_HAS_PATCH FALSE PARENT_SCOPE)
	set(BM_STAMP_TREE "" PARENT_SCOPE)
	set(BM_STAMP_EXTRA "${_extra}" PARENT_SCOPE)
	set(BM_STAMP_TOKEN "" PARENT_SCOPE)
	set(BM_STAMP_HOLDERS "${_holders}" PARENT_SCOPE)
	set(BM_STAMP_WORKDIR "${_workdir}" PARENT_SCOPE)
	set(BM_STAMP_BUILDDIR "${_builddir}" PARENT_SCOPE)
	set(BM_STAMP_ENV "${_env}" PARENT_SCOPE)

	set(_has FALSE)
	if(NOT "${_patches}" STREQUAL "" AND EXISTS "${_patches}"
			AND NOT "${_workdir}" STREQUAL "" AND NOT "${_holders}" STREQUAL "")
		file(STRINGS "${_patches}" _plist)
		if(_plist)
			set(_has TRUE)
		endif()
	endif()

	string(REGEX REPLACE "[^A-Za-z0-9_.-]" "_" _safe "${_id}")
	set(_token "")
	if(_has)
		set(BM_STAMP_HAS_PATCH TRUE PARENT_SCOPE)
		_bm_stamp_load_git("${_env}")
		file(MAKE_DIRECTORY "${_holders}")
		set(_lock "${_holders}.lock")
		file(LOCK "${_lock}" GUARD FUNCTION TIMEOUT 600 RESULT_VARIABLE _lk)
		if(NOT _lk EQUAL 0)
			_bm_log_message(COMPONENT FATAL
				"stamp: could not lock ${_lock} for ${_id}")
		endif()
		_bm_stamp_reap_count("${_holders}" _live)
		set(_token "${_holders}/${_safe}_${_stage}.lock")
		file(WRITE "${_token}" "${_id}\n")
		file(LOCK "${_token}" GUARD PROCESS RESULT_VARIABLE _tlk)
		if(NOT _tlk EQUAL 0)
			file(REMOVE "${_token}")
			_bm_log_message(COMPONENT FATAL
				"stamp: could not hold ${_token}")
		endif()
		math(EXPR _live "${_live} + 1")
		if(_live EQUAL 1)
			_bm_stamp_git_reset("${_workdir}")
			_bm_stamp_apply_manifest("${_workdir}" "${_patches}")
		endif()
		set(BM_STAMP_TOKEN "${_token}" PARENT_SCOPE)
	endif()

	_bm_stamp_tree_sha("${_srcdir}" "${_builddir}" _tree)
	set(BM_STAMP_TREE "${_tree}" PARENT_SCOPE)
	set(_want "tree=${_tree}\nextra=${_extra}")
	set(_match FALSE)
	set(_keyfile "${_builddir}/bm-stamp.key")
	if(EXISTS "${_keyfile}")
		file(READ "${_keyfile}" _have)
		string(STRIP "${_have}" _have)
		if("${_have}" STREQUAL "${_want}")
			set(_match TRUE)
		endif()
	endif()

	if(_match)
		if(_has)
			file(LOCK "${_token}" RELEASE)
			file(REMOVE "${_token}")
			_bm_stamp_reap_count("${_holders}" _left)
			if(_left EQUAL 0)
				_bm_stamp_git_reset("${_workdir}")
			endif()
			set(BM_STAMP_TOKEN "" PARENT_SCOPE)
		endif()
		set(BM_STAMP_SKIP TRUE PARENT_SCOPE)
		set(BM_STAMP_HOLD FALSE PARENT_SCOPE)
		file(WRITE "${_builddir}/bm-stamp.hit" "${_id}\n")
		_bm_log_message(COMPONENT STATUS "stamp hit ${_id}")
	else()
		if(_has)
			set(BM_STAMP_HOLD TRUE PARENT_SCOPE)
		endif()
		file(REMOVE "${_builddir}/bm-stamp.hit")
		_bm_log_message(COMPONENT DEBUG "stamp miss ${_id}")
	endif()
endfunction()

## @brief Finish a stage that did not skip.
## @param[in] _commit `create` writes `bm-stamp.key` (install, after oficios).
##            `refresh` updates it only when it already exists (build).
##            Anything else does not write. Configure passes `0`.
##            Build must not create the key: the install command in the same
##            ninja would see a hit and skip publishing.
## @note A patched root is reset when no live holder remains. The digest
##       stored is the one computed in `_bm_stamp_enter`, before the build
##       could write into the srcdir.
function(_bm_stamp_leave _commit)
	if(BM_STAMP_HAS_PATCH AND BM_STAMP_HOLD AND NOT "${BM_STAMP_TOKEN}" STREQUAL "")
		_bm_stamp_load_git("${BM_STAMP_ENV}")
		set(_lock "${BM_STAMP_HOLDERS}.lock")
		file(LOCK "${_lock}" GUARD FUNCTION TIMEOUT 600 RESULT_VARIABLE _lk)
		if(NOT _lk EQUAL 0)
			_bm_log_message(COMPONENT FATAL
				"stamp: could not lock ${_lock} to release")
		endif()
		if(EXISTS "${BM_STAMP_TOKEN}")
			file(LOCK "${BM_STAMP_TOKEN}" RELEASE)
			file(REMOVE "${BM_STAMP_TOKEN}")
		endif()
		_bm_stamp_reap_count("${BM_STAMP_HOLDERS}" _left)
		if(_left EQUAL 0)
			_bm_stamp_git_reset("${BM_STAMP_WORKDIR}")
		endif()
	endif()
	set(_keyfile "${BM_STAMP_BUILDDIR}/bm-stamp.key")
	set(_do FALSE)
	if("${_commit}" STREQUAL "create")
		set(_do TRUE)
	elseif("${_commit}" STREQUAL "refresh" AND EXISTS "${_keyfile}")
		set(_do TRUE)
	endif()
	if(_do)
		if("${BM_STAMP_TREE}" STREQUAL "" OR "${BM_STAMP_EXTRA}" STREQUAL "")
			_bm_log_message(COMPONENT FATAL "stamp: refusing to record an empty key")
		endif()
		file(MAKE_DIRECTORY "${BM_STAMP_BUILDDIR}")
		file(WRITE "${_keyfile}"
			"tree=${BM_STAMP_TREE}\nextra=${BM_STAMP_EXTRA}\n")
	endif()
endfunction()
