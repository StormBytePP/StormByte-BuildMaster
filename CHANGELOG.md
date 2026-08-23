# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
