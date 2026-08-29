# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

2.x versus 1.0.x is a different product: declarative graph, no generated
fragment to `include()`, no public dependant factories, no public
`create_cmake_component` / `create_meson_component`. A 1.x
`CMakeLists.txt` will not configure. That is the point.

### Added

- **Declarative component graph.**
  `buildmaster_depend(source dest)` is order-only (id, stage name, or
  existing CMake target). `buildmaster_link(source dest)` waits and
  links. `dest` may be a component (all produced libs), a library spec
  (`name` / `subdir/name`), a target, or an archive path. Spec dests are
  listed on the source install `OUTPUT` so Ninja has a production rule.
- **`buildmaster_link` always records `buildmaster_depend`.**
  `buildmaster_link(A B)` before `buildmaster_component(B)` still defers
  A. A spec or on-disk archive stays link-only. Duplicate *explicit*
  edges are WARNING + no-op; internal auto-deps do not warn.
  Unresolvable dest at finalize is FATAL.
- **Deferred materialization.** Registration only stores metadata.
  Fragments and stage targets exist at the end of parent configure
  (`cmake_language(DEFER)` on `CMAKE_SOURCE_DIR`). Declaration order
  does not matter. Components without edges still configure during
  parent configure; components with edges configure at build time under
  `<id>_configure`.
- **Eager INTERFACE stub.** `add_library(<id> INTERFACE)` at
  registration so a sibling `ALIAS` / `target_link_libraries` before
  DEFER does not see a missing target.
- **`buildmaster_component`.** Backend is inferred from `srcdir`
  (`CMakeLists.txt` vs `meson.build`; both or neither is FATAL).
  Same arity as the old `create_*` wrappers. Neutral `options` list:
  `CFLAGS`, `CXXFLAGS`, `CPPFLAGS`, `LDFLAGS`, `INCLUDES`,
  `DEFINITIONS` — private to the nested compile, appended to the parent
  job / toolchain. Other keys FATAL. optstr (`LINK=`, `PC=`, …)
  unchanged.
- **Optional build directory slot.** BuildMaster assigns
  `${CMAKE_CURRENT_BINARY_DIR}/bm/<id>` when omitted.
  `file(MAKE_DIRECTORY)` is idempotent. The caller is responsible if
  that directory already has leftover files.
- **`LINK=` / `LINK={…}`.** Raw system linker names on the component or
  meta INTERFACE. They propagate to whoever links that id. Not BM
  nodes. Revives 1.x `LINK_EXTRA` under a shorter name.
- **`LINKFLAGS=` / `LINKFLAGS={…}`.** Raw linker flags via
  `target_link_options` on the same INTERFACE. Groups: `WINDOWS`,
  `LINUX`, `MAC`, `UNIX` (`UNIX` = Linux + macOS). A group that does
  not apply is skipped at INFO. Unknown platform key is FATAL.
- **`RENAME` (flag, default ON).** Post-install normalize of variant
  basenames. Headers mode ignores it.
- **`WHOLE`.** Whole-archive link of produced static archives.
- **`STRIPRES` (flag, default ON).** After `RENAME`, strip `*.res` from
  static MSVC / clang-cl archives.
- **`BUILDONLY` + `buildmaster_repack`.** Build without publishing to
  the shared prefix; merge listed archives into one IMPORTED target.
- **Helper `.pc` (`PC={…}`).** After install, write
  `${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/<Name>.pc` for *this* prefix.
  FATAL if the path already exists. Not a portable package.
- **Meta `TOOLCHAIN` inheritance.** `buildmaster_meta(…
  "TOOLCHAIN=<profile>")` copies the profile onto members and onto
  empty dests. An explicit child `TOOLCHAIN` wins.
- **Hooks.** `buildmaster_hook_component(id fn alias [CAPTURE …])` /
  `buildmaster_hook_graph(fn alias [CAPTURE …])`. `fn` must exist at
  registration. Alias is the only order key (ASCII ascending).
  `CAPTURE` snapshots by copy.
- **Unified logging.** `_bm_log_message(<module> <level> "<text>"
  [<indent>])` is internal. Public `buildmaster_message(<level>
  "<text>" [<indent>])` always uses module `USER`. `WARNING` and
  `FATAL` are never filtered.
- **Silent env runner** replays nested `[BuildMaster/…]` lines live;
  the full child log is dumped on failure.
- Prefix search injection so nested compiles see the shared install
  tree.
- Harness + consumer tests for recursive cmake/meson, helper `.pc`,
  meta-toolchain, LINKFLAGS, hooks, late link, raw `LINK=`, duplicate
  edges, reset-then-patch, PC clobber (install FATAL).

### Changed

- **Breaking — public API is `buildmaster_*` only.** Eighteen commands
  (see `public_functions.txt`). Internals are `_bm_<craft>_*` and are
  not a supported API. In particular:
  - `create_cmake_component` / `create_meson_component` /
    `create_*_headers_component` / `create_component` are gone.
    Use `buildmaster_component`.
  - `component_link` → `buildmaster_link`.
  - `component_dependency` → `buildmaster_depend`.
  - `component_prerequisite` → `buildmaster_prerequisite`.
  - `component_repack` → `buildmaster_repack`.
  - `create_meta_component` → `buildmaster_meta`.
  - `meta_component_add` → `buildmaster_meta_add`.
  - `create_git_*` → `buildmaster_git_{fetch,switch,reset,patch}`.
  - `file_download` / `file_download_cached` / `file_decompress` →
    `buildmaster_download{,_cached}` / `buildmaster_decompress`.
  - `buildmaster_on_component_materialize` →
    `buildmaster_hook_component`.
  - `buildmaster_on_graph_finalized` → `buildmaster_hook_graph`.
  - `buildmaster_message` public arity is `<level> "<text>" [<indent>]`.
    Module is always `USER`.
  - `ensure_build_dir`, `sanitize_for_filename`, import hints,
    toolchain profile/validate, archiver lookup, checksum and git
    marker are internal.
- **Breaking — no generated fragment to `include()`.** No out-variable.
- **Breaking — dependant factories are gone.** Use
  `buildmaster_component` + `buildmaster_depend` (or
  `buildmaster_link`, which waits).
- **Breaking — `LINK_EXTRA` is gone.** Graph nodes:
  `buildmaster_link`. Raw system libs: `LINK=`.
- **Breaking — `BUILDMASTER_DEBUG` is gone.** Use
  `BUILDMASTER_LOGLEVEL`. `BUILDMASTER_VERBOSE` is unchanged.
- **Breaking — options string.** One optional trailing `KEY=value;…`
  (`INDENT`, `TOOLCHAIN`, `RENAME`, `WHOLE`, `BUILDONLY`, `STRIPRES`,
  `PC={…}`, `LINK=`, `LINKFLAGS=`). `;` inside `{…}` is not a pair
  break. Unknown keys warn; extra positionals are fatal.
- Stage `COMMENT`: configure stays CMake/Meson; compile and install
  use `[BuildMaster/Ninja]`.
- Root `CMakeLists.txt` includes helpers before `init_vars`, so
  `add_subdirectory(buildmaster)` alone bootstraps a consumer.
- Root configure includes `GNUInstallDirs`.

### Fixed

- Git patch lost the race with eager configure: flush runs at
  registration and again *before* materialize (reset then patch once
  per root).
- `buildmaster_git_patch` then `buildmaster_git_reset` used to apply
  and immediately `reset --hard`. Ops flush as reset + clean, then
  apply.
- Cached download under `cmake -P` did not see the log helper; templates
  now include log + checksum.
- Dead second `function(component_dependency)` (now
  `buildmaster_depend`) in `graph.cmake`.
- `RENAME` ignored Unix-style `.a` on Windows when the contract asked
  for `.lib`.
- `TOOLCHAIN=` rejected valid names when the dump was not a CMake list.
- Meson `--native-file` followed the outer job instead of the component
  profile.
- Log modules empty during DEFER.
- Produced paths `${prefix}//libfoo.a` when the host skipped
  `GNUInstallDirs`.
- Component id equal to produced name (`add_library` twice).
- Import-hint arity at nested finalize.
- ALIAS before DEFER.
- Windows DLL lookup under `lib/` / wrong stem case.
- Missing prefix `-I`/`-L` on nested compile.
- Interrupted CMake configure left cache without `build.ninja`.
- Empty Meson `-Dbuildtype=`.
- Empty `@NPROC@` at DEFER.
- File helpers only created a target; the `-P` script now also runs at
  the call so the artifact exists before `buildmaster_component`.
- Initialization now uses logging.

[Unreleased]: https://github.com/StormBytePP/StormByte-BuildMaster/compare/1.0.1...HEAD

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
- Incomplete component toolchain snapshots (missing tool `*_SRCDIR` / `ENV_*`) that led to failures such as `File /templates/configure.cmake.in does not exist` when nested projects created further components
- **Nested `add_subdirectory(buildmaster)` no longer corrupts the shared `toolchain.cmake`:** when `BUILDMASTER_CONFIGURED` is already TRUE (host loaded the parent dump as `CMAKE_TOOLCHAIN_FILE`), the root `CMakeLists.txt` loads helpers, propagates vars, and returns—without `toolchain_reset` / module re-export / `toolchain_write`. Previously a nested bootstrap cleared the registry, re-wrote only root-level keys, and overwrote the parent dump, which then broke deeper components with empty template roots (`/templates/configure.cmake.in`, `/component_shared.cmake.in`)
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
