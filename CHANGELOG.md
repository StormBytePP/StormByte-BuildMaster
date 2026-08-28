# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Git patch applied twice at configure:** `create_git_patch_file` then `create_git_reset_file` flushed on every register, so the log was apply → `reset --hard` → apply again. Patch is only queued; flush runs reset then patch once (on reset, or DEFER at end of `CMAKE_SOURCE_DIR` when there is no reset). A second flush for the same root is a no-op.
- **Cached download under `cmake -P`:** `file_download_cached.cmake.in` called `file_checksum_correct`, which does not exist in a script-mode process. The cache hit path now uses `file(<ALGO>)` only. Configure of a consumer that already has the tarball on disk (SQLite amalgamation) no longer dies with `Unknown CMake command "file_checksum_correct"`.

[Unreleased]: https://github.com/StormBytePP/StormByte-BuildMaster/compare/2.0.0...HEAD

## [2.0.0] - 2026-08-28

### Added
- **Declarative component graph:**
  - `component_dependency(source, dest)` — order-only edges (component id, stage name, or existing CMake target).
  - `component_link(source, dest)` — link plus order; `dest` may be a component (all produced libs), a library spec (`name` / `subdir/name`), a target, or an archive path.
  - Library-spec link destinations are also listed on the source component’s install `OUTPUT` so Ninja has a production rule (replaces the old `LINK_EXTRA` role).
- **Deferred materialization:** `create_*` only registers metadata; fragments and stage targets are created at the end of parent configure (`cmake_language(DEFER)` on `CMAKE_SOURCE_DIR`). Declaration order does not matter.
- **Eager vs deferred configure:** components without dependency edges still configure during parent configure; components with edges configure at build time under `<id>_configure` (same behaviour as the former dependant templates).
- **Subcomponent libdir paths:** library specs may be `<name>` or `<subdir>/<name>` under `BUILDMASTER_INSTALL_LIBDIR`.
  - Imported target name replaces `/` with `_`; helper `buildmaster_parse_subcomponent()`.
- **`library_import_hint` / `library_import_static_hint`:** optional 4th argument `subdir`.
- **`RENAME` component option (flag, default ON):** post-install normalize of variant basenames to produced paths (`zs` → `z`, etc.); headers mode ignores it.
- **`WHOLE` component / meta option:** whole-archive link of produced static archives (one linear group per consumer; ELF / Mach-O / MSVC).
- **`STRIPRES` component option (flag, default ON):** after `RENAME`, strip `*.res` members from static MSVC / clang-cl archives via `lib` / `llvm-lib` `/LIST` + `/REMOVE`. Silent no-op on other toolchains; warning on shared / headers.
- **`BUILDONLY` + `component_repack`:** build without publishing to the shared prefix; merge listed archives with the host archiver into one IMPORTED target.
- **Helper `.pc` (`PC={…}`):** after install (RENAME + STRIPRES), write `${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/<Name>.pc` for **internal** consumers of this prefix — not a portable upstream package.
  - Syntax: `PC={VERSION=1.2.3;NAME=foo;DESCRIPTION=…;ENABLED=ON}`. `;` inside `{…}` is not a pair break.
  - `VERSION` is required when enabled. `ENABLED=OFF` skips the file and does not require `VERSION`.
  - `NAME` defaults to the first produced spec; `DESCRIPTION` defaults to the component title.
  - `Requires` comes from direct `component_link` destinations that themselves have PC enabled (one hop, no metas).
  - `Cflags` are component extras minus parent `CMAKE_C{,XX}_FLAGS`; include tokens (`-I` / `/I` / `-isystem`) are dropped (prefix include is already in the BM env).
  - `Libs` is `-L${libdir}` plus `-l<produced>` for each produced spec. `prefix` / `libdir` / `includedir` are the BuildMaster install tree.
  - **FATAL:** bare `PC` / `PC=ON` without `{…}`; enabled PC + `BUILDONLY`; `PC={…}` on a meta; destination path already exists (do not clobber an upstream `.pc`).
  - Unknown inner keys warn and are ignored. Parser helper: `buildmaster_parse_component_pc()`.
- **Meta `TOOLCHAIN` inheritance:** `create_meta_component(… "TOOLCHAIN=<profile>")` no longer ignores the key. After leaves are known and before cmake/meson materialize, the profile is copied onto members (nested metas included) and onto `component_dependency` / `component_link` dests from that meta that have no `TOOLCHAIN` yet. An explicit child `TOOLCHAIN` is kept. Two metas inheriting different profiles onto the same empty destination is fatal.
- **Unified logging API** (`log.cmake`):
  - `buildmaster_message(<module> <level> "<text>" [<indent>])` — only public way to print from BuildMaster (and recommended for consumers).
  - Levels (ascending, quieter filter): `LOWLEVEL`, `DEBUG`, `INFO`, `WARNING`, `STATUS`, `FATAL`.
  - `BUILDMASTER_LOGLEVEL` (cache or env, default `STATUS`). Unknown names are fatal and list the accepted set.
  - `FATAL` is never filtered. `WARNING` is hidden when the current level is stricter than `INFO`.
  - Format: `[BuildMaster/<Module>]: …` for `STATUS`; `[<LEVEL>][BuildMaster/<Module>]: …` otherwise (no space between brackets; level and module labels padded).
  - Header is never indented; optional indent applies only to the body.
  - Ninja `COMMENT` lines use the same `STATUS` header via `buildmaster_log_comment()`.
  - Module `USER` (`User`) is reserved for parent projects (`buildmaster_message(USER STATUS "Setting up the library" 1)`). CMake `message()` is discouraged in consumers and forbidden inside BuildMaster except `log.cmake`.
- **Harness + consumer tests:** recursive cmake/meson chains, Meson rename fixture, order-independent fixture, helper-`.pc` fixture (`Requires` check), meta-toolchain, and a Logger-style consumer (`add_subdirectory(buildmaster)` + sibling library, no extra includes).
- **Documented layout contract:** BuildMaster and every DSL-driven dependency must be **sibling directories** under the same parent. Registration `CMakeLists.txt` is not the nested `srcdir`.
- **Prefix search injection** (`env/prefix_search.cmake`): after `clean_cflags` and before stage `configure_file` / Meson `_MESON_*_ARGS` / env runners, inject the shared install prefix into compile and link search paths:
  - UNIX: `-I${BUILDMASTER_INSTALL_INCLUDEDIR}` and `-L${BUILDMASTER_INSTALL_LIBDIR}` on `CFLAGS` / `CXXFLAGS` / `LDFLAGS` and `CMAKE_{C,CXX,EXE,SHARED,MODULE}_LINKER_FLAGS`.
  - Windows (MSVC-like): `/I` and `/LIBPATH:` on the same flag variables, **and** prepend `${BUILDMASTER_INSTALL_INCLUDEDIR}` / `${BUILDMASTER_INSTALL_LIBDIR}` to process `INCLUDE` and `LIB` (case-preserving).
  - Nested `BUILDMASTER_CONFIGURED` persists those values through `update_toolchain.cmake` so a second configure does not drop them.
- **Eager INTERFACE stub:** `add_library(<id> INTERFACE)` at `create_*_component` time (graph registration), so `ALIAS` / `target_link_libraries` in a sibling `lib/` that runs *before* DEFER finalize does not see a missing target.

### Changed
- Stage `COMMENT` headers: **configure** stays `[BuildMaster/CMake]` / `[BuildMaster/Meson]`; **compile and install** use `[BuildMaster/Ninja]` (Ninja is the driver for those targets). Git post-install reset stays `[BuildMaster/Git]`.
- Stage targets (`*_build` / `*_install`, CMake and Meson) use `COMMENT` instead of `cmake -E echo`. Ninja without `-v` shows only `Compiling …` / `Installing …`; the full `cd … && cmake -P …` line appears with `ninja -v` or `VERBOSE=1`.
- **Breaking — logging:**
  - `BUILDMASTER_DEBUG` (cache and env) is removed and ignored. Use `BUILDMASTER_LOGLEVEL` (`LOWLEVEL` / `DEBUG` / `INFO` / `STATUS` / `WARNING` / `FATAL`).
  - `BUILDMASTER_VERBOSE` is unchanged and independent (live compiler/linker output only).
- **Breaking — fully declarative `create_*` API:**
  - No out-variable and no consumer `include()` of a generated fragment.
  - Signature: `create_cmake_component(<id> <title> <srcdir> <builddir> <options> <mode> <produced> [options_string])` (and Meson / headers analogues).
  - Removed public `create_*_dependant_component` / `create_*_headers_dependant_component`; use `create_*` + `component_dependency`.
  - Removed `LINK_EXTRA` from the options string; use `component_link`.
  - `create_*_stages` are **internal** (not part of the supported public API).
- **Breaking — options string:** single optional trailing `KEY=value;…` (keys `INDENT` / `INDENT_LEVEL`, `TOOLCHAIN`, `RENAME`, `WHOLE`, `BUILDONLY`, `STRIPRES`, `PC={…}`). `;` inside `{…}` is not a pair break. Unknown keys warn; extra positionals are fatal.
- **Internal layout:** `component/helpers.cmake` owns registry, graph, and shared fragment emit; `component/cmake` and `component/meson` own wrappers and backend materialize (`create_*_stages`). Templates under `component/templates/`; `BUILDMASTER_COMPONENT_TEMPLATEDIR`.
- Install stages do not write empty placeholder archives; missing produced paths after optional `RENAME` are fatal. Header-only stamps still apply.
- Root `CMakeLists.txt` includes `helpers.cmake` (and thus `log.cmake`) before `init_vars.cmake`, so `add_subdirectory(buildmaster)` alone is a valid consumer bootstrap — no extra `include(…/helpers.cmake)` required after the subdirectory.
- Root configure includes `GNUInstallDirs` so `CMAKE_INSTALL_LIBDIR` / `INCLUDEDIR` exist even when the host forgot them; `BUILDMASTER_INSTALL_LIBDIR` is no longer an empty path with a doubled slash.

### Fixed
- **`TOOLCHAIN=` in nested CMake:** `BUILDMASTER_KNOWN_TOOLCHAINS` coming from the toolchain dump could be a newline- or space-separated string. `list(FIND)` then rejected valid names (`gcc`, `clang`, …). Validation now normalizes that value to a CMake list; the dump exports a semicolon-separated list.
- **Meson `--native-file`:** `create_meson_stages` always picks `native_<profile>.ini` for `TOOLCHAIN=<name>`, or the file for **this** process’s compiler family (`CMAKE_C_COMPILER_ID` / clang-cl) when `TOOLCHAIN` is omitted. It no longer keeps the outer job’s default native file across a swapped toolchain. Setup does not fall back to bare `CC=` when a native file exists, so ccache/sccache stay keyed to the compiler actually used.
- **Consumer bootstrap / log modules:** `buildmaster_message(COMPONENT …)` during deferred finalize no longer dies with `unknown log module 'COMPONENT'. Accepted:` (empty list). Modules are registered when `log.cmake` is loaded from the root `CMakeLists.txt`, not only when a harness included helpers first.
- **Install prefix without `GNUInstallDirs`:** produced paths were `${prefix}//libfoo.a` and `RENAME` looked in the prefix root instead of `lib/` / `lib64/`. BuildMaster now loads `GNUInstallDirs` itself.
- **Stage templates after sibling `add_subdirectory`:** `BUILDMASTER_TOOLS_CMAKE_SRCDIR` (and friends) resolve to the checkout, so `configure.cmake.in` is found instead of `/configure.cmake.in`.
- **Component id equal to produced name:** fragment templates created `add_library(<id> INTERFACE)` and then `add_library(<id> STATIC|SHARED IMPORTED)`. CMake rejects the second target (`StormByte` / `StormByte` in Logger). The IMPORTED target is now `<name>__bm_imported` when `<name>` already exists; the INTERFACE `<id>` still links that archive. Host `target_link_libraries(… <id>)` is unchanged.
- **`library_import_hint` arity in nested DEFER finalize:** 1.x callers used 3 arguments; 2.0 added an optional 4th (`subdir`). Finalize now dispatches 3-arg vs 4-arg instead of dying on “called with incorrect number of arguments”.
- **ALIAS before DEFER:** `StormByte::Logger` (and any consumer `add_library(<ns>::<name> ALIAS <id>)`) no longer fails because `<id>` did not exist until end-of-`CMAKE_SOURCE_DIR`. The INTERFACE stub exists at registration; wiring (`INTERFACE_INCLUDE_DIRECTORIES`, link of `__bm_imported`) happens at finalize.
- **Windows DLL “no candidate” under `lib/`:** `normalize_install_outputs` registers shared outputs on `BINDIR` as well as `LIBDIR`, and keeps the original stem case so `StormByte.dll` is not looked up as `stormbyte.dll`.
- **Missing `-I` / `-L` / `INCLUDE` / `LIB` on nested configure:** 1.x env runners injected the install prefix; 2.0 dropped it, so Logger’s nested compile of `log.cxx` / `manipulators.cxx` never saw `StormByte/platform.h`. CMake and Meson stages now call `buildmaster_apply_install_search_paths` after `clean_cflags` and before writing runners / `_MESON_*_ARGS`. Nested configure no longer passes empty `-DCMAKE_C_FLAGS=` / `-DCMAKE_CXX_FLAGS=`.
- **Consumer test layout:** `.github/tests/consumer` matches the real Logger/Buffer contract: sibling `thirdparty/`, `cmake_policy(SET CMP0079 NEW)`, `add_subdirectory(thirdparty)` then `add_library(Consumer::Dep ALIAS …)` with **no** `if(NOT TARGET)` guard and **no** DEFER workaround.
- **Nested CMake configure skip:** `configure.cmake.in` treated `CMakeCache.txt` as “already configured”. An interrupted first run left cache + `CMakeScratch` and no `build.ninja`; the next parent configure skipped the stage and Ninja failed with `loading 'build.ninja'`. Skip now requires both the cache and `build.ninja` (same idea as Meson setup).
- **Meson `-Dbuildtype=`:** `create_meson_stages` now maps `CMAKE_BUILD_TYPE` to a concrete Meson choice (`Debug` → `debug`, `RelWithDebInfo` → `debugoptimized`, `MinSizeRel` → `minsize`, `Release` or empty/multi-config → `release`). An empty `@MESON_BUILD_TYPE@` made Meson reject `Value "."` and abort setup (e.g. PostgreSQL).
- **Meson/CMake `--jobs` / `--parallel`:** `NPROC` from `ProcessorCount()` lived only in the BuildMaster subdirectory. `PARENT_SCOPE` stops at `thirdparty/` and `persist.cmake` only cached `BUILDMASTER_*` / `ENV_*`, so `@NPROC@` was empty at DEFER and Meson aborted with `argument -j/--jobs: expected one argument`. `NPROC` is now a cache INTERNAL (minimum 1).
- **File helpers at configure:** `file_download`, `file_download_cached` and `file_decompress` still create a named target and do not use an out-var / `include()`. The generated `-P` script also runs during the call so the artifact is on disk before `create_*_component`. Scripts stay idempotent. `DEPENDS` is build-graph only. A `component_dependency` on the file target is only needed when a later rebuild must precede a deferred configure.
- **Git patch vs reset order:** `create_git_patch_file` then `create_git_reset_file` applied the patch at configure and immediately `reset --hard`, so the tree that compiled was the unpatched commit (Crypto++ `stdext` on MSVC). Ops are queued per repository and flushed as reset + clean, then apply. Post-install still resets and cleans so a successful build does not leave a dirty worktree.
- **Consumer git-patch smoke:** the dependant library source ships a compile-breaking typo and `0001-fix-typo.patch`, and registers patch then reset in that order. Smoke fails if the patch is not still applied at build time.

[2.0.0]: https://github.com/StormBytePP/StormByte-BuildMaster/releases/tag/2.0.0

## [1.0.1] - 2026-08-26

### Added

#### Header-only components
- New library mode `headers` in `create_component` / `create_cmake_stages` / `create_meson_stages`
- Templates `component_headers.cmake.in` and `component_headers_dependant.cmake.in`
  - `INTERFACE` library only (no `IMPORTED` static/shared archives)
  - `target_include_directories(... SYSTEM INTERFACE "${BUILDMASTER_INSTALL_INCLUDEDIR}")`
  - Depends on `<component>_install` like library modes
- Install `OUTPUT` is a stamp file `${builddir}/.buildmaster_headers_installed` (avoids empty `OUTPUT` / CMP0175 with header-only trees)
- `install_exec` (CMake and Meson) creates missing stamp paths after a successful install
- Simple API:
  - `create_cmake_headers_component`
  - `create_cmake_headers_dependant_component`
  - `create_meson_headers_component`
  - `create_meson_headers_dependant_component`
- Build stage is kept for a uniform graph (header-only projects are typically no-ops)

#### Nested linker and binutils propagation
- Nested **CMake** configures forward the parent toolchain so third-party builds match the top level:
  - Linker: `CMAKE_LINKER_TYPE`, `CMAKE_LINKER`, `CMAKE_C_COMPILER_LINKER`, `CMAKE_CXX_COMPILER_LINKER`, `CMAKE_MT`
  - Archiver / nm: `CMAKE_AR`, `CMAKE_C_COMPILER_AR`, `CMAKE_CXX_COMPILER_AR`, `CMAKE_RANLIB`, `CMAKE_C_COMPILER_RANLIB`, `CMAKE_CXX_COMPILER_RANLIB`, `CMAKE_NM`
  - `CMAKE_MODULE_LINKER_FLAGS` (in addition to existing EXE/SHARED linker flags)
- `tools/cmake/update_toolchain.cmake` registers non-empty linker and archiver cache entries for the BuildMaster toolchain dump (paths normalized to forward slashes)
- Nested **Meson** setups:
  - Build `_MESON_LINK_ARGS` from `CMAKE_EXE_LINKER_FLAGS`
  - Linker selection via `buildmaster_fuse_ld_flag()` (driver-safe `-fuse-ld=` flavors only):
    - `CMAKE_LINKER_TYPE=LLD` / forced LLD → `-fuse-ld=lld-link` (Windows) or `-fuse-ld=lld` (elsewhere)
    - `CMAKE_LINKER_TYPE=MSVC` → `-fuse-ld=link`
    - Else map `CMAKE_LINKER` / `BM_TC_LINKER` basename (`lld`, `ld.lld`, `gold`, `mold`, `bfd`, …); system `ld` and absolute paths such as `/usr/bin/ld` emit **no** `-fuse-ld` (GCC rejects path-form `-fuse-ld=/usr/bin/ld`)
  - Pass `AR` / `RANLIB` into Meson setup via `cmake -E env` (from `CMAKE_AR` / `CMAKE_RANLIB` or the process environment)
- **Env runners** (`runner_linux.sh.in` / `runner_windows.bat.in`) export `AR`, `RANLIB`, and `NM` so any command launched through `ENV_RUNNER` inherits the same binutils as nested CMake/Meson
- `env/init_vars.cmake` and `update_env_runner()` resolve `AR` / `RANLIB` / `NM` from `CMAKE_AR` / `CMAKE_RANLIB` / `CMAKE_NM` or `ENV{…}` before regenerating the runner scripts

#### Per-component toolchains
- Optional trailing `TOOLCHAIN` argument on the **simple** component API (`create_cmake_*` / `create_meson_*`, including headers and dependant variants) **and** on the **atomic stage** helpers (`create_cmake_stages` / `create_meson_stages`); the same profile applies to that component’s configure, build and install whether stages are generated via the factory or wired explicitly
- Named profiles under `toolchain/profiles/`: `gcc`, `clang`, `clang-cl`, `msvc`
  - `clang`: LLD required on Linux; LLD **not** forced on macOS
  - `clang-cl`: LLD (`lld-link`) + `llvm-lib` (Windows only)
  - `msvc`: `cl` + `link.exe` + `lib.exe` (Windows only)
  - `gcc`: system linker/archiver (LLD not forced)
- New module `toolchain/` (init, helpers, profiles): validation, platform guards, profile load
- **Toolchain file registry** (single source of truth for parent and component dumps):
  - `buildmaster_toolchain_reset` / `export` / `export_raw` / `write`
  - Modules register state in `*/update_toolchain.cmake`; the parent `toolchain.cmake` is written once at the end of the BuildMaster root `CMakeLists.txt`
  - `buildmaster_toolchain_write_component`: parent registry snapshot + profile compiler/binutils `CACHE FORCE` overlay (no hand-maintained variable list in stage generators)
- `buildmaster_clean_ldflags()` / `buildmaster_clean_cflags()` strip known-incoherent tokens by profile:
  - `msvc`: remove LLD / Clang-LTO switches; other flags preserved
  - `clang-cl`: remove MSVC LTCG tokens (`/GL`, `/LTCG` and variants) that clang-cl ignores or mishandles
- Component-local env runners (normal + silent) when `TOOLCHAIN` is set; parent global runners are not rewritten
- When `TOOLCHAIN` is set, configure and build status lines (and dependant configure `COMMENT`) include `(with toolchain <name>)`; omitted when inheriting the parent job
- IPO/LTO is never enabled by a profile; if the parent already had IPO on, nested stages keep a coherent setting (`CMAKE_INTERPROCEDURAL_OPTIMIZATION_*` / Meson `b_lto`) without re-injecting MSVC `/GL`
- Fully backward compatible: omitting `TOOLCHAIN` keeps previous behaviour

### Fixed

- **Per-component `TOOLCHAIN` and nested BuildMaster installs:** components with a toolchain override no longer bootstrap a second install tree under the component build dir (e.g. `…/buffer/build/thirdparty/buildmaster/install`). Nested configures load a component toolchain file built from the parent registry so `BUILDMASTER_INSTALL_*`, template dirs (`BUILDMASTER_TOOLS_CMAKE_SRCDIR`, …) and `ENV_*` stay unified with the parent; only compilers/binutils are overridden
- Incomplete component toolchain snapshots (missing tool `*_SRCDIR` / `ENV_*`) that led to failures such as `File /configure.cmake.in does not exist` when nested projects created further components
- **Nested `add_subdirectory(buildmaster)` no longer corrupts the shared `toolchain.cmake`:** when `BUILDMASTER_CONFIGURED` is already TRUE (host loaded the parent dump as `CMAKE_TOOLCHAIN_FILE`), the root `CMakeLists.txt` loads helpers, propagates vars, and returns—without `toolchain_reset` / module re-export / `toolchain_write`. Previously a nested bootstrap cleared the registry, re-wrote only root-level keys, and overwrote the parent dump, which then broke deeper components with empty template roots (`/configure.cmake.in`, `/component_shared.cmake.in`)
- **Meson nested setups with system `ld`:** no longer pass `-fuse-ld=/usr/bin/ld` (or other absolute linker paths) into `c_link_args` / `cpp_link_args`. GCC rejects path-form `-fuse-ld=`; `buildmaster_fuse_ld_flag()` only emits driver flavor names, so PostgreSQL and other Meson components configure correctly under a default Linux linker
- **clang-cl + inherited MSVC LTCG flags:** when the parent job uses clang-cl (or a stage selects `TOOLCHAIN clang-cl`), `create_cmake_stages` / `create_meson_stages` strip `/GL` and `/LTCG*` from C/CXX and linker flags instead of forwarding them. clang-cl was warning `unknown argument ignored` for `/GL`; IPO remains driven by `CMAKE_INTERPROCEDURAL_OPTIMIZATION_*` and Meson `b_lto`, not by those MSVC-only switches
- **Meson on Windows (MSVC-like toolchains):** do **not** inject `/std:c11` into nested Meson `c_args`. That flag did not fix clang-cl PostgreSQL C99 probes (UCRT `complex`/`tgmath` vs Clang `_Complex`) and could break real `cl` builds (e.g. Postgres `VA_ARGS_NARGS_` / non-constant initializers). Prefer `TOOLCHAIN msvc` for PostgreSQL on Windows. Upstream projects set their own C standard; only `/Z7` is still appended for CodeView on MSVC-like drivers
- Meson stages: `SCCACHE_DIR` path normalization wrote into `CCACHE_DIR` instead of `SCCACHE_DIR`, so sccache cache directories could be lost or overwrite the ccache path during nested Meson setup
- Dependant configure targets (`component_*_dependant.cmake.in`): under the **Ninja** generator, long configures (e.g. FFmpeg `meson setup`) looked hung — the silent env runner swallowed `message(STATUS)` from the configure `-P` script. Makefiles still printed progress. Now each dependant configure target sets `USES_TERMINAL` and a clear `COMMENT "Configuring <component>"` so Ninja shows the step as soon as it starts
- Dependant configure progress on **Windows + Ninja**: `cmake -E echo "Configuring …"` plus the same `COMMENT` concatenated on one line (`Configuring x265Configuring x265`). Dropped the redundant `echo`; a single `COMMENT` is enough
- Dependant components: `indent_level` is forced to `0` in `create_component` when a dependency is set. Hierarchical tabs are only meaningful in the parent **configure** log (`message_indented`); dependant stages run at **build** time and must not inherit plugin-level indentation in status lines or nested stage scripts

[1.0.1]: https://github.com/StormBytePP/StormByte-BuildMaster/releases/tag/1.0.1

## [1.0.0] - 2026-08-21

Initial public release of **StormByte-BuildMaster**: a CMake DSL to configure, build, install and consume external CMake and Meson projects as first-class parts of a parent tree, with stage-based orchestration, explicit targets, coherent environment propagation, portable static-library bundling, and controlled failure propagation across the dependency graph.

### Added

#### Core orchestration
- Parent-configure generation of configure / build / install stage scripts for external projects
- Explicit stage targets: `<component>_configure`, `<component>_build`, `<component>_install`
- `<component>_build` depends on `<component>_configure`
- Shared install prefix (`BUILDMASTER_INSTALL_DIR`) and generated script tree across the whole dependency graph
- Safe recursive nesting via `BUILDMASTER_CONFIGURED` (single initialization, no prefix fights)
- IMPORTED targets (static and shared, including MSVC import libraries and DLLs) wired to install stages
- INTERFACE libraries also depend on `<component>_install` so parent `target_link_libraries` waits for a successful install
- Simple API: `create_cmake_component`, `create_meson_component`
- Dependant variants: `create_cmake_dependant_component`, `create_meson_dependant_component`
- Advanced/explicit API: `create_cmake_stages`, `create_meson_stages`
- Project version exposed as `BUILDMASTER_VERSION` and shown in the bootstrap status line

#### Fail-fast and failure propagation
- Optional `BUILDMASTER_FAIL_FAST` (env or `-D`; truthy: `1` / `ON` / `TRUE` / `YES`; default OFF)
- On stage failure with fail-fast ON: write `markers/buildmaster.failed` and `markers/<component_id>.failed`
- Later stages print `Skipped <component title>` and exit non-zero when the global marker exists
- Env runners refuse further work if the global fail marker is present (`Skipped due to previous errors`)
- Unique `buildmaster_build_init` target resets the markers directory at the start of every parent build (Ninja, Make, `cmake --build`)
- Markers directory under `${BUILDMASTER_BINDIR}/markers/` (no persistent success stamps)
- Fail-fast OFF writes no markers so independent components can keep building (cache warming with ccache/sccache)
- Stage exec scripts (`configure_exec` / `build_exec` / `install_exec` for CMake; `setup_exec` / `compile_exec` / `install_exec` for Meson) centralize exit-code handling and marker writes

#### Environment and toolchain
- Platform env runners (Linux/macOS shell, Windows batch) with silent variants
- Propagation of compilers, flags, `PATH`, `PKG_CONFIG_PATH`, `LIB`, `INCLUDE`
- Compiler-cache support (`CMAKE_*_COMPILER_LAUNCHER`, `CCACHE_DIR`, `SCCACHE_DIR`) into child CMake and Meson builds
- Optional full live output (`BUILDMASTER_DEBUG`) and verbose compile-only output (`BUILDMASTER_VERBOSE`)
- Failure diagnostics: silent runners dump captured logs on non-zero exit

#### CMake and Meson backends
- Nested CMake configures with Ninja, toolchain file, PIC, LTO and launcher injection
- Nested Meson setup/compile/install with matching environment and library type control
- Parallel builds via `NPROC` / `CMAKE_BUILD_PARALLEL_LEVEL`
- Stage targets depend on `buildmaster_build_init` when available

#### File helpers
- Cache-aware downloads (`file_download_cached`) with hash verification and retries
- Force downloads (`file_download`) with progressive backoff
- Flexible `EXPECTED_HASH` (`ALGORITHM=digest`, including forms such as `SHA3_256=…`; bare digest defaults to SHA256)
- Portable archive extraction (`file_decompress`) via `file(ARCHIVE_EXTRACT)`
- Strict path-traversal protection and consistent status messages

#### Git helpers
- Generated fragments for fetch, reset/clean, patch apply and branch switch
- API binds each operation to a **component id** (same id as `create_*_component`):
  - `create_git_reset_file(out, component_id, title, repo)`
  - `create_git_patch_file(out, component_id, title, repo, patches)`
  - `create_git_fetch(out, component_id, title, repo)`
  - `create_git_switch_branch(out, component_id, title, repo, branch)`
- Registered git scripts run at the **start of `<component>_configure`** (before nested CMake/Meson setup), in registration order
- Call `create_git_*` **before** `create_*_component` / `create_*_stages` for that component
- Optional aggregate target `buildmaster_clean` (`BUILDMASTER_CLEAN_RESET_REPOS`, default ON)
  - Only components that used `create_git_*` are affected
  - Per component: `git reset --hard` + `git clean -fd` from the git toplevel (`rev-parse --show-toplevel`)
  - **Invalidates that component’s configure** (removes Meson `build.ninja` / `meson-private`, or CMake `CMakeCache.txt` / `build.ninja` under the component build dir)
  - Next `cmake --build` / `ninja` / `make` re-enters `<component>_configure` → re-applies git ops → nested setup → build
  - Controlled exclusively via environment variable (falsy: `0` / `OFF` / `FALSE` / `NO`)
  - Propagated to nested BuildMaster instances through the toolchain file
  - **Not** wired to the generator’s native `clean` target (unreliable with Ninja); use:
    `cmake --build <builddir> --target buildmaster_clean`
- Automatic **per-component** post-install git reset
  - After a successful `*_install`, runs `reset --hard` + `clean -fd` **only for that component’s repo**
  - Does not invalidate configure (avoids full reconfigure after every install)
  - Removes the need for manual `POST_BUILD` reset hooks in consumer projects (e.g. VPX, VMAF)

#### Static library support
- Portable static archive merging (`create_bundle_static_libraries`):
  - Linux: GNU `ar -M` (MRI)
  - macOS: `libtool -static`
  - Windows: `lib /OUT:`
- Optional post-install rename of static libraries to canonical names

#### Platform support
- Linux, Windows (MSVC) and macOS (x86_64 and Apple Silicon)
- Extra-tool registration (e.g. bundled `pkgconf`)

### Notes

- Requires CMake ≥ 3.20; Meson and Ninja when using the corresponding backends.
- Stage scripts are generated at parent configure time — change `BUILDMASTER_DEBUG` / `BUILDMASTER_VERBOSE` / `BUILDMASTER_FAIL_FAST` / `BUILDMASTER_CLEAN_RESET_REPOS` and re-run CMake to regenerate them.
- Designed as a building block for multi-dependency projects (e.g. FFmpeg plugin graphs, multi-bitdepth codecs, database client bundles).

[1.0.0]: https://github.com/StormBytePP/StormByte-BuildMaster/releases/tag/1.0.0
