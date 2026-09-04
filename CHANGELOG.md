# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Summary]

BuildMaster is a small CMake DSL for a **graph of other people’s builds**.
You declare each dependency once — how it is produced, what it waits on — and the parent gets one shared prefix instead of a pile of `ExternalProject` / FetchContent glue.
CMake and Meson trees are first-class.

Typical use: add the submodule, `add_subdirectory`, declare components, then `depend` / `link`.
Declaration order does not matter.
The public surface is ten commands on purpose; everything else is internal.

If you landed here from a release link and have not read the tree:

- How to write a component, every optstr key, and the contract: [README.md](https://github.com/StormBytePP/StormByte-BuildMaster/blob/master/README.md)
- The ten names, and nothing else: [public_functions.md](https://github.com/StormBytePP/StormByte-BuildMaster/blob/master/public_functions.md)
- Porting an older caller: [MIGRATE.md](https://github.com/StormBytePP/StormByte-BuildMaster/blob/master/MIGRATE.md)

## [Unreleased]

### Added

### Changed

### Fixed

### ToDo

- [ ] **Idempotent stage stamps.** After `ninja <meta>_install` the
      leaf `_build` / `_install` / `_configure` files must stay
      current. A later `ninja ffmpeg_install` (or any consumer of the
      same leaves) must be a no-op for work that already published
      to the prefix. Today Ninja treats those nodes as dirty and
      re-enters nested `cmake --build` / `meson compile`.
- [ ] **Re-apply `GIT={PATCH}` before any rebuild.** Post-install
      `RESET` restores the work tree (correct: the submodule stays
      clean). That also removes the patches. A dirty nested
      `build.ninja` then runs `cmake --regenerate-during-build` on
      *upstream* sources (`cmake_minimum_required` too old, missing
      guards, …) and the compile stage dies. Either queue PATCH
      again as a dependency of `_build` / regenerate, keep a
      patched worktree until the graph is idle, or turn off
      regenerate-during-build on BM builddirs. Samplerate on CMake
      4 is the canary.
- [ ] **`BUILDMASTER_JOBS`.** Cap concurrent BM stage scripts
      (configure/build/install) independently of `ninja -jN`.
      Sync log lines so two oficios do not interleave. Needs a
      portable lock around `_bm_log_message` (Unix + Windows `.ps1`
      runners). Empty `COMMENT` on `add_custom_command`; banners
      go through log only.
- [ ] **Named install phases.** Split the current `_install` bag
      into explicit pre-install oficios (`rename` on NOINSTALL
      BUILDDIR) and post-install oficios (`rename` on prefix,
      `strip_res`, `pc`, git RESET). Keep `_install` as the public
      stamp until callers migrate. Document that NOINSTALL still
      runs the “install” wrapper (it does not `cmake --install`).
- [ ] **Optstr tokenizer.** One scanner for nested `{…}` lists
      (`PATCH={a;b}`, `LINK={…}`). Per-option code only interprets
      tokens. Stops CMake from splitting `PATCH={file1;file2}`.
- [ ] **`validate/`** for contract FATALs (factory / options / meta /
      group / demand). Operation FATALs stay in `-P` workers.
- [ ] Allow BuildMaster anywhere on disk, not only as a sibling of
      `thirdparty`. Sole rule: `add_subdirectory(BM)` before first
      use.
- [ ] **Install-tree cache (2.1).** Each component may restore its
      *installed* prefix from a blob cache instead of compile+install.
      Staging prefix per id, then an atomic copy into
      `BUILDMASTER_INSTALL_DIR` (same layout as a live install: libs,
      headers, `*Config.cmake`, `.pc`). Not a builddir cache
      (ccache/sccache already cover objects).
      Default cache key: worktree SHA *after* PATCH, hash of the
      applied patch files, toolchain profile, `CMAKE_BUILD_TYPE`,
      IPO on/off, `mode`, `produced`, host OS/arch. SHA of the
      unpatched submodule pin is not enough.
      Extra key material via optstr (name TBD, e.g. `CACHEKEY=` /
      `CACHE={…}`): caller-supplied tokens so a leaf like FFmpeg
      distinguishes `-Dlibx265=enabled` vs disabled without hashing
      the entire options list by default. Empty extra key = default
      only. HIT must be a no-op for `_build`/`_install`; MISS writes
      the staging tree after a successful install. `NOINSTALL` never
      publishes (no cache write). `REPACK` caches the publisher
      archive, not each member, unless the member itself is cached.
      Partial HIT (lib without Config.cmake) is FATAL, not a silent
      fallback. Needs the 2.0.1 idempotent stamps first or restore
      and rebuild will race.
- [ ] **RENAME should rewrite installed `.pc` files to the produced stem.**
      `RENAME` already moves `libfoo-static.a` / `jpeg-static.lib` /
      `libpng16.a` to the `produced` name. The matching
      `*.pc` (`Libs: -lpng16`, `-ljpeg`, `-ltesseract55`) is left
      untouched, so Meson/`pkg-config --static --libs` still looks
      for the *pre-rename* artifact. Consumers then fail with
      LNK1104 / “library not found” even though the archive exists
      under the produced stem.
      After renaming an archive, scan
      `${BUILDMASTER_INSTALL_DIR}/**/pkgconfig/*.pc` (or the
      component’s own `.pc`) and rewrite `-l<old-stem>` (and
      `Name:` if it is only the old stem) to `-l<produced>`.
      Do not invent new `.pc` files. Shared-library sonames and
      CMake `*Config.cmake` / `*Targets.cmake` are a separate
      ticket (`find_package` paths vs `pkg-config`).

[Unreleased]: https://github.com/StormBytePP/StormByte-BuildMaster/compare/2.0.0...HEAD

## [2.0.0] - 2026-09-04

2.x versus 1.0.x is a different product: declarative graph, no generated fragment to `include()`, no public dependant factories, no public `create_cmake_component` / `create_meson_component`.
A 1.x `CMakeLists.txt` will not configure.
That is the point.

What 1.0.1 already did internally (headers mode, per-component toolchains, nested binutils, env runners) is still there; the caller and the declaration shape changed.

### Added

- **Declarative component graph.**
  `buildmaster_depend(source dest)` is order-only (id, stage name, or existing CMake target).
  `buildmaster_link(source dest)` waits **and** records the same depend edge, so `buildmaster_link(A B)` before `buildmaster_component(B)` still defers A.
  `dest` may be a component (all produced libs), a library spec (`name` / `subdir/name`), a target, or an archive path.
  Spec dests are listed on the source install `OUTPUT` so Ninja has a production rule.
  A spec or on-disk archive stays link-only.
  Duplicate *explicit* edges are WARNING + no-op; internal auto-deps do not warn.
  Unresolvable dest at finalize is FATAL.
- **Deferred materialization + eager INTERFACE stub.**
  Registration only stores metadata.
  Fragments and stage targets exist at the end of parent configure (`cmake_language(DEFER)` on `CMAKE_SOURCE_DIR`).
  Declaration order does not matter.
  Components without edges still configure during parent configure; components with edges configure at build time under `<id>_configure`.
  `add_library(<id> INTERFACE)` at registration so a sibling `ALIAS` / `target_link_libraries` before DEFER does not see a missing target.
- **`buildmaster_component`.**
  Backend is inferred from `srcdir` (`CMakeLists.txt` vs `meson.build`; neither + `headers` → `none`).
  Dual markers are FATAL unless `BACKEND=cmake` or `BACKEND=meson` (allowed set: `BUILDMASTER_FACTORY_BACKENDS`).
  `BACKEND=` empty or an unknown name is FATAL.
  `SOURCE=<rel>` is applied **before** that detect: the value is always under the positional `srcdir` (a leading `/` is still a child of `srcdir`, not an absolute path).
  Escape above the component `srcdir` (or above the host `CMAKE_SOURCE_DIR`) is FATAL **before** any existence probe.
  After the boundary check, a missing directory is FATAL.
  The resolved tree must contain a `.git` only when `GIT={…}` is also set; `SOURCE=` itself is not a git root.
  Arity is `id title srcdir options mode produced [optstr]`.
  Mode is `static`, `shared`, `headers`, or `executable`.
  `options` is a backend-agnostic CMake list of `KEY=value` (a single string is one pair).
  Idioms `CFLAGS`, `CXXFLAGS`, `CPPFLAGS`, `LDFLAGS`, `INCLUDES`, `DEFINITIONS` are rewritten for the nested compile and **append** to the parent job / toolchain.
  Every other key is forwarded as `-DKEY=value` to the nested CMake configure or Meson setup (Meson also uses `-D`).
  A leading `-D` / `-d` / `/D` on the key is stripped.
  Private to that nested step, not INTERFACE.
  `none` ignores the list.
  `none` outside headers mode is FATAL unless `NOINSTALL` is set; a unique backend is still used when present.
- **Mode `executable`.**
  Produced specs are binary stems under `BUILDMASTER_INSTALL_BINDIR` (`<stem>` on Unix, `<stem>${CMAKE_EXECUTABLE_SUFFIX}` on Windows; never `.exe.exe`).
  The parent stub is still `add_library(<id> INTERFACE)` — it is not an `IMPORTED` executable.
  Nested CMake/Meson build the binary; `LINK` / `LINKFLAGS` apply to that nested link.
  Linux gcc/clang: nested *and* parent `CMAKE_<LANG>_LINK_EXECUTABLE` wrap `<LINK_LIBRARIES>` with `-Wl,--start-group` / `--end-group` so a static exe that lists provider before consumer (ld.bfd single pass) still resolves, including under LTO.
  Darwin ld64 and MSVC/clang-cl do not get those flags.
  SHARED/MODULE recipes are unchanged.
  `WHOLE` on the executable itself is INFO and ignored.
  A leaf of a `WHOLE` meta is the same INFO skip: the meta must not emit `-WHOLEARCHIVE:<bindir>/<stem>.exe` / `--whole-archive` of the binary.
  `STRIPRES` does not run.
  `PC={…}` ENABLED is FATAL.
  `REPACK` on the executable itself is FATAL.
  A first-level `depend`/`link` dest that is `executable` is not a REPACK member (INFO skip; not FATAL as a “publishing member”).
  A leaf of a `REPACK` meta that is `executable` is the same INFO skip and is not an INPUT of the merge.
  Extra `buildmaster_link` dests that are raw library specs are **not** folded as IMPORTED archives on an executable.
  Produced exe stems are never `BM_LINKS_LIBNAMES` and never land on a consumer or meta link line (`gzip.exe` is not a library).
  Membership in a meta is order-only (`*_install`).
  Oficios: `rename_executable` (when `RENAME`) then `outputs`.
- **Assigned build directory.**
  There is no public builddir argument.
  The graph uses `${CMAKE_CURRENT_BINARY_DIR}/bm/<id>` and `file(MAKE_DIRECTORY)`.
  The path is an internal property, not part of the DSL.
- **Outline groups.**
  `buildmaster_group(id [title])` and `buildmaster_group_add(group member…)`.
  A group is **not** a component, a meta, or a link: no targets, no edges, no install.
  After the graph is complete it only walks members in **addition order** and prints configure banners with indent.
  Nested groups are allowed; a member must not contain a group.
  Cycles and id clashes with a component/meta/group are FATAL (caller file:line).
  Configure-time messages inherit the walk indent; compile/install stay flat.
  Eager vs deferred is unchanged — the outline is cosmetic order, not a wait edge.
- **Headers island (mode `headers`, with or without a backend).**
  No backend, or `NOINSTALL` headers: private.
  Direct consumers get a quoted `-I` on *that* id’s nested configure only (CMake `CMAKE_{C,CXX}_FLAGS` and Meson `c_args` / `cpp_args`).
  It does not recurse through further BM components, runners, or INTERFACE.
  Publishing headers (backend + not `NOINSTALL`) install into the shared prefix; the prefix `-I` already covers them.
  Several private islands on one consumer accumulate several `-I`.
- **`FILES={URL=…;NAME=…;UNPACK;SOURCE[=rel];FORCE;MD5=|SHA256=|EXPECTED_HASH=…}`.**
  Declarative download on `buildmaster_component` (meta + any FILES group is FATAL).
  Always cached under `BUILDMASTER_DOWNLOADSDIR` (`FORCE` refetches).
  Unpack is `${BUILDMASTER_BINDIR}/files/<NAME>/`, **before** nested configure (eager components included).
  Inner `SOURCE` (at most one group, requires `UNPACK`) *is* the srcdir after unpack — the positional path is ignored by design (WARNING).
  That key is **not** the component optstr `SOURCE=`.
  Other unpacked groups inject a private `-I` on that id only (same rule as the headers island).
  `GIT={…}` + FILES `SOURCE` is FATAL.
  Replaces the 1.x `file_download*` + dependant-component pattern.
- **`LINK=` / `LINK={…}`.**
  Raw system linker *names* on the component or meta INTERFACE.
  They propagate to whoever links that id.
  Not BM nodes.
  Revives 1.x `LINK_EXTRA` under a shorter name.
- **`LINKFLAGS=` / `LINKFLAGS={…}`.**
  Raw linker *flags* (`/FORCE:MULTIPLE`, `-Wl,-Bsymbolic`) for the **nested** cmake/meson link only.
  Groups: `WINDOWS`, `LINUX`, `MAC`, `UNIX` (`UNIX` = Linux + macOS).
  A group that does not apply is skipped at INFO.
  Unknown platform key is FATAL.
  Folded into that id’s OPTIONS at finalize (`CMAKE_EXE/SHARED/MODULE_LINKER_FLAGS` or Meson `c_link_args` / `cpp_link_args`).
  **Not** `target_link_options` on the INTERFACE — a consumer of this id does not inherit the flags.
  Meta: WARNING + ignore (no nested link).
  Headers: WARNING + ignore.
- **`GIT={FETCH;SWITCH=<branch>;RESET;PATCH=<file>;ROOT=<rel>;TITLE=…}`.**
  Srcdir git work on `buildmaster_component`.
  `ROOT=` is always under the component `srcdir` (same isolation as optstr `SOURCE=`): escape FATAL before existence, missing tree FATAL, work tree that is the host `CMAKE_SOURCE_DIR` FATAL.
  Flush order is fixed: FETCH → SWITCH → RESET → PATCH (PATCH order is declaration order).
  Relative `PATCH=` is from `CMAKE_CURRENT_SOURCE_DIR`.
  Empty `GIT` / `GIT={}` is WARNING.
  Meta + any git op is FATAL.
  `FETCH` / `RESET` are inner flags.
  Post-install reset runs only when a PATCH was queued, and only inside that work tree (`ROOT=`).
- **`RENAME` (flag, default ON).**
  Post-install normalize of variant basenames.
  Libraries: oficio `rename_library`, worker `component/rename/normalize_install_libraries.cmake`.
  Executables: oficio `rename_executable`, worker `normalize_install_executables.cmake`.
  Headers mode never registers a rename oficio (stamps are not archives).
- **`WHOLE`.**
  Whole-archive link of produced **static** archives.
  Ignored (INFO) on headers and executable, including when that executable is a leaf of a `WHOLE` meta.
- **`STRIPRES` (flag, default ON).**
  After `RENAME`, strip `*.res` from static MSVC / clang-cl archives.
  Shared / headers / executable never strip.
- **`NOINSTALL` + `REPACK`.**
  Bare `NOINSTALL` builds without publishing to the shared prefix (artifacts stay under the component BUILDDIR; `RENAME` still runs there).
  `NOINSTALL=` and truthy `NOINSTALL=ON|TRUE|1|YES` enable with WARNING (`write NOINSTALL, not NOINSTALL=…`).
  Falsy values (`OFF|FALSE|0|NO`) are FATAL (`omit the key to install`).
  `BUILDONLY` is removed and FATAL (`use NOINSTALL`).
  Meta `NOINSTALL` is prevalent: finalize stamps every member.
  A unique backend is still used when detected; dual markers stay FATAL.
  `buildmaster_meta(id title "REPACK")` plus `buildmaster_meta_add` merges every produced *static* archive of the member leaves into one prefix archive named after the meta id.
  Wait edge is `_install` for every static member, including `NOINSTALL`.
  That target does not call `cmake --install` / `meson install` when `NOINSTALL`; it only runs oficios (rename, outputs, strip) on the BUILDDIR so REPACK sees the produced stem, not `foo-static.lib`.
  Shared members that install stay INTERFACE (WARNING: they are not folded into the pack).
  `NOINSTALL` + shared as a `REPACK` member is FATAL (the `.so`/`.dll` is not in the prefix and the builddir is not public).
  `REPACK` on `buildmaster_component` is valid for **static** only: first-level depend/link dests that are NOINSTALL static are the members; the publisher archive in the prefix is rewritten (`POST_BUILD` on `<id>_install`).
  `REPACK` + `NOINSTALL` on the same id is FATAL.
  `REPACK` + headers or executable on the same id is FATAL.
  Shared + `REPACK` on a component is WARNING + skip at finalize.
  Zero static members is FATAL.
  An `executable` dest of a REPACK publisher is skipped (INFO), not a member.
  An `executable` leaf of a `REPACK` meta is the same INFO skip and is not a merge INPUT.
  `buildmaster_link` to a `NOINSTALL` dest is FATAL (order-only: `buildmaster_depend`, or publish via a `REPACK` meta / component).
- **Helper `.pc` (`PC={…}`).**
  After install, write `${BUILDMASTER_INSTALL_LIBDIR}/pkgconfig/<Name>.pc` for *this* prefix.
  FATAL if the path already exists.
  Not a portable package.
  `NOINSTALL` + enabled `PC=` is FATAL (no shared prefix).
  `executable` + enabled `PC=` is FATAL.
- **Post-install oficios.**
  Sealed GLOBAL `BUILDMASTER_COMPONENT_<id>_INSTALL_OFICIOS` is the ordered list (`rename_library` | `rename_executable`, `outputs`, `strip_res`, `pc`).
  `_bm_install_rules_write` emits only those files under `scripts/install_rules/` and a rules aggregator with bare `include()`.
  Templates have no `if(@_BM_*_ENABLED@)` feature flags.
  CMake and Meson share the same oficios.
  The stage wrapper is `install_library.cmake.in` → `<id>_install_library.cmake` (`install_exec` is gone).
  `_BM_BUILDONLY` remains the NOINSTALL token in wrappers and in the `outputs` oficio.
- **Meta `TOOLCHAIN` inheritance.**
  `buildmaster_meta(… "TOOLCHAIN=<profile>")` copies the profile onto members and onto empty dests.
  An explicit child `TOOLCHAIN` wins.
- **Hooks.**
  `buildmaster_hook_component(id fn alias [CAPTURE …])` / `buildmaster_hook_graph(fn alias [CAPTURE …])`.
  `fn` must exist at registration.
  Alias is the only order key (ASCII ascending).
  `CAPTURE` snapshots by copy.
  A hook is not an edge and does not flip the component to deferred.
- **Unified logging.**
  `_bm_log_message(<module> <level> "<text>" [<indent>])` is internal.
  Public `buildmaster_message(<level> "<text>" [<indent>])` always uses module `USER`.
  `WARNING` and `FATAL` are never filtered.
  When `BUILDMASTER_LOG_NOCOLOR` is `OFF`, lines are painted: STATUS stays the default CMake color; WARNING yellow (`message(NOTICE)`); INFO green; DEBUG cyan; LOWLEVEL dim; FATAL red.
  `ON` leaves the text unpainted.
- **`BUILDMASTER_LOG_NOCOLOR`.**
  Truthy env or `-D` (`1` / `ON` / `TRUE` / `YES`) stores `ON` and turns ANSI off; anything else is `OFF` (color on).
  Same pattern as `BUILDMASTER_VERBOSE`.
  Default `OFF`.
  Written into `propagate_vars` and the toolchain dump so nested `-P` scripts see the same switch.
- **Silent env runner**
  Replays nested `[BuildMaster/…]` lines live; the full child log is dumped on failure.
- **Prefix search.**
  Nested CMake gets `BUILDMASTER_INSTALL_DIR` prepended on `CMAKE_PREFIX_PATH` (runners export it; empty install dir is FATAL).
  Nested pkg-config still gets `PKG_CONFIG_PATH` first.
  `find_package` / `*Config.cmake` under the shared prefix resolve without per-leaf `-DFOO_ROOT=`.
- **Toolchain translator.**
  One pass per profile: drop foreign dialect and IPO tokens (`-flto*`, `-ffat-lto-objects`, `-fno-fat-lto-objects`, `/GL`, `/LTCG`, `-fuse-ld=`), rewrite `-I`/`-L` ↔ `/I`/`/LIBPATH:`, then inject this profile’s linker flavor and IPO *without* writing `-flto`/`-ffat-lto-objects` back onto gcc/clang `CMAKE_C{XX}_FLAGS`.
  Those compile tokens live in `BM_TC_IPO_COMPILE_OPTIONS` so the leaf `CMAKE_INTERPROCEDURAL_OPTIMIZATION` module is the single dialect (`-DCMAKE_<LANG>_COMPILE_OPTIONS_IPO=`).
  LD still gets `-flto` or `/LTCG`.
  MSVC/clang-cl still write `/GL` or `-flto` on C/CXX.
  `-fuse-ld=` as before (see Fixed).
  Called from CMake/Meson stages before the env runner refresh.
  `-fPIC` stays on gcc/clang; it is dropped on msvc.
- **On-demand tools.**
  Bootstrap always initializes `ninja`.
  The archiver is **not** a tool: it is a field of the `TOOLCHAIN=` profile (`CMAKE_AR` / Meson `[binaries] ar` and `ld`).
  `cmake`, `meson`, `git`, and `file` initialize on first use: backend wrappers (`cmake` / `meson`), `GIT={…}` / `FILES={…}` on the optstr, or a pending `FILES SOURCE` after the tree is unpacked.
  Extra tools live under `tools/extra/<id>/` (`pkgconfig` is the only extra in this release) and start only via `REQUIRE_TOOL=<id>` / `REQUIRE_TOOL={id;id2}` on `buildmaster_component` or `buildmaster_meta`.
  Empty `REQUIRE_TOOL` / `REQUIRE_TOOL=` / `REQUIRE_TOOL={}` is WARNING and ignored.
  An id that is not in `BUILDMASTER_TOOLS_EXTRA_KNOWN` (or whose directory is missing) is FATAL — BM never silently falls back to a same-named system binary.
  A second request is a no-op.
  `PC={…}` only writes a helper `.pc`; it does **not** demand `pkgconfig`.
  `pkgconfig` still prefers a working system pkg-config/`pkgconf` and builds the bundled tree only when that probe fails.
  `BUILDMASTER_INITIALIZE_EXTRA_TOOLS` is gone.
  Configure prints `Setting up tools: <name>` only when that tool actually starts.
  Compiler profiles follow the same rule: configure loads the parent profile inferred from `CMAKE_C_COMPILER` / `CMAKE_CXX_COMPILER` and writes only `native_default.ini` plus that profile’s Meson file.
  Any other name (`gcc`, `clang`, `clang-cl`, `msvc`) is demanded when a component or meta sets `TOOLCHAIN=` to it.
  Missing cc/cxx/ar/ld is FATAL on *that* id and names the parent profile plus `CMAKE_C_COMPILER`.
  A gcc job does not need clang, lld or llvm-ar on PATH.
  There is no `REQUIRE_TOOL=gcc`.
- **Harness + consumer tests**
  Recursive cmake/meson, helper `.pc`, meta-toolchain, LINKFLAGS (OPTIONS fold + no INTERFACE leak; meta ignore), hooks, late link, raw `LINK=`, duplicate edges, `GIT={RESET;PATCH=…}`, reset-then-patch, PC clobber (install FATAL), `REPACK` meta and component (including NOINSTALL members that emit `*-static` until `_install` rename), private-headers `-I`, `FILES=` unpack / SOURCE, FILES-on-meta FATAL, outline groups (CMake + Meson leaves), `NOINSTALL` (build without prefix publish), `REQUIRE_TOOL=pkgconfig` bundled path, `BUILDONLY` removed / `NOINSTALL=OFF` FATAL, mode `executable` (plain CMake/Meson, link a BM static, rename stem, NOINSTALL, REPACK publisher that ignores an executable dest, WHOLE meta + SHARED host that must not see the exe, `exe-rescan` static provider-before-consumer under `IPO=fat`), negatives `exe-pc` / `exe-repack` / `exe-empty-produced`, toolchain profile `ar`/`ld` text check (only the parent profile plus any `TOOLCHAIN=` actually used), translator dialect + `/link` order.
- **Harness entry `run_buildmaster_main`.**
  One target: smoke (install stages + artifacts) already depends on `run_buildmaster_negative` and `run_buildmaster_consumer` (`consumer_nested`); then a wiped sibling `consumer_ci` bindir.
  Local one-liner: `rm -rf build/harness && cmake -S .github/tests/harness -B build/harness -G Ninja && cmake --build build/harness --target run_buildmaster_main`.
- **Configure report (`BUILDMASTER_VERBOSE`).**
  After graph hooks, the primary bootstrap prints `BuildMaster <version> Configuration:` (module `Report`): parent toolchain paths/flags, then an alphabetical component table (`ID` / `TYPE` / `LINK`) with one-level `NEEDED BY` and explicit overrides only (`CFLAGS`, `CXXFLAGS`, `FILES`, `LINKFLAGS`, `NOINSTALL`).
  Groups are omitted.
  Row order is readability, not the graph walk.
  Nested bootstraps stay silent.
- **`IPO=` on component and meta.**
  Per-id LTO, independent of parent `CMAKE_INTERPROCEDURAL_*`.
  Omitted → inherit the parent (and leftover `-flto` / `/GL` tokens).
  `IPO` / `IPO=` / `IPO=on` → thin LTO (gcc/clang: `CMAKE_INTERPROCEDURAL_OPTIMIZATION` + compile-options `-flto`; clang-cl `-flto` on C/CXX; msvc `/GL` + `/LTCG`).
  `IPO=off` strips every IPO token even if the parent has IPO on.
  `IPO=fat` is thin plus `-ffat-lto-objects` on gcc/clang compile options only (`BM_TC_IPO_COMPILE_OPTIONS` / Meson `c_args`), never a second copy on `CMAKE_C_FLAGS` (that mixed `-flto -ffat-lto-objects` with CMake’s `-flto=auto -fno-fat-lto-objects` and the last token won).
  MSVC and clang-cl treat fat as on; no fat objects on LD.
  Darwin: AppleClang rejects `-ffat-lto-objects`, so `fat` is `on` (`-flto` only) and one STATUS notice is emitted per configure.
  Invalid values are FATAL.
  A meta with `IPO=` stamps members that omit the key (same destinations as `TOOLCHAIN=`); an explicit child `IPO=` wins and a second meta does not FATAL.
  CMake/Meson stages call `_bm_tc_translate_component`; Meson `-Db_lto=` follows the same mode.
  Harness: translator `on`/`off`/`fat` vs parent cache and `BM_TC_IPO_COMPILE_OPTIONS`; `exe-rescan` (provider before consumer + `IPO=fat`); negative `ipo-bad` (`IPO=nope`).

### Changed

- **Breaking — public API is `buildmaster_*` only.**
  Ten commands (see [public_functions.md](public_functions.md)): `buildmaster_component`, `buildmaster_depend`, `buildmaster_link`, `buildmaster_meta`, `buildmaster_meta_add`, `buildmaster_group`, `buildmaster_group_add`, `buildmaster_hook_component`, `buildmaster_hook_graph`, `buildmaster_message`.
  Internals are `_bm_<craft>_*` and are not a supported API.
  In particular:
  - `create_cmake_component` / `create_meson_component` / `create_*_headers_component` / `create_component` are gone. Use `buildmaster_component`.
  - `component_link` → `buildmaster_link`.
  - `component_dependency` → `buildmaster_depend`.
  - `create_meta_component` → `buildmaster_meta`.
  - `meta_component_add` → `buildmaster_meta_add`.
  - `create_git_*` / `buildmaster_git_*` → `GIT={…}` on the component.
  - `file_download` / `file_download_cached` / `file_decompress` → `FILES={…}` on the component. There is no public `buildmaster_download*` / `buildmaster_decompress` / `buildmaster_prerequisite`.
  - `component_repack` / `buildmaster_repack` are gone. Use `buildmaster_meta(… "REPACK")` + `buildmaster_meta_add`, or `REPACK` on a static `buildmaster_component`.
  - `buildmaster_on_component_materialize` → `buildmaster_hook_component`.
  - `buildmaster_on_graph_finalized` → `buildmaster_hook_graph`.
  - `buildmaster_message` public arity is `<level> "<text>" [<indent>]`. Module is always `USER`.
  - `ensure_build_dir`, `sanitize_for_filename`, import hints, toolchain profile/validate, archiver lookup, checksum and git marker are internal.
- **Breaking — `INDENT=` is gone as a layout knob.**
  The optstr key still parses so old trees configure, but it is WARNING + ignored (`Use buildmaster_group / buildmaster_group_add for configure outline`).
  Visual indent comes only from the group walk at configure time.
  Compile and install comments stay at indent 0.
- **Breaking — no public build directory.**
  `buildmaster_component` / `_bm_backend_*_create` do not take a builddir.
  The 2.0/2.1 arity heuristic is gone.
  Extra arguments are FATAL.
  `_bm_path_builddir` is gone.
  Callers that still pass a path get the arity FATAL (or CMake unknown-command if they called the deleted helper).
- **Breaking — no `buildmaster_repack`.**
  There is no public merge command, no `OUTPUT=` / `INPUTS=` parse arguments, no path tokens.
  Members of a `REPACK` meta *are* the inputs.
  The published stem is the meta id.
  Callers that still invoke `buildmaster_repack` get CMake’s unknown-command FATAL.
- **Breaking — no generated fragment to `include()`.**
  No out-variable.
- **Breaking — dependant factories are gone.**
  Use `buildmaster_component` + `buildmaster_depend` (or `buildmaster_link`, which waits).
- **Breaking — `LINK_EXTRA` is gone.**
  Graph nodes: `buildmaster_link`.
  Raw system libs: `LINK=`.
- **Breaking — `LINKFLAGS` is not INTERFACE.**
  There is no `target_link_options` on `<id>`.
  Flags fold into that id’s nested OPTIONS only.
  A parent that links the component does **not** inherit `-Wl,-Bsymbolic` / `/FORCE:MULTIPLE`.
  Put flags on the id that actually builds, or on the final executable yourself.
  Meta `LINKFLAGS` is WARNING + ignored.
- **Breaking — `BUILDONLY` is gone.**
  Write `NOINSTALL`.
  The old key is FATAL.
  There is no `NOINSTALL=OFF`.
- **Breaking — `BUILDMASTER_DEBUG` is gone.**
- **Breaking — options string.**
  Flag keys may omit `=`.
  Known flags: `RENAME`, `NOINSTALL`, `WHOLE`, `STRIPRES`, `PC`, `GIT`, `REPACK`, `FILES`, `REQUIRE_TOOL`.
  `BUILDONLY` is accepted by the splitter only so the parser can FATAL.
  `BACKEND=` and `SOURCE=` require `KEY=value`.
  `INDENT=` is accepted only to warn.
  `;` inside `{…}` is not a pair break.
  Unknown keys warn; extra positionals are fatal.
- **Breaking — install wrapper.**
  `install_exec.cmake.in` / `<id>_install_exec.cmake` are gone.
  Wrapper is `install_library.cmake.in`.
  Generated rules live under `scripts/install_rules/`.
  Worker `normalize_install_outputs.cmake` is `normalize_install_libraries.cmake`.
- **Archiver is toolchain, not a tool.**
  `CMAKE_AR` and Meson `[binaries] ar` / `ld` come from the component `TOOLCHAIN=` profile: `msvc` → `lib.exe` + `link.exe`; `clang-cl` → `llvm-lib` + `lld-link`; Linux `clang` → `llvm-ar` + `ld.lld`; Darwin `clang` → cctools `ar` + `ld`; Linux `gcc` → binutils `ar` + `-fuse-ld=bfd`; Darwin `gcc` → Homebrew `gcc-N` + cctools `ar`/`ld` (no `CMAKE_LINKER_TYPE=BFD`).
  A clang-cl parent does not force `llvm-lib` onto an `msvc` leaf or onto REPACK merge.
  Missing AR on a profile is FATAL (incomplete toolchain), not an optional tool miss.
- **Stage COMMENT:**
  configure stays CMake/Meson; compile and install use `[BuildMaster/Ninja]`.
- **Root `CMakeLists.txt` includes helpers before `init_vars`,** so `add_subdirectory(buildmaster)` alone bootstraps a consumer.
- **Root configure includes `GNUInstallDirs`.**
- **Post-install git reset + clean** runs only after a PATCH, and only in the component work tree (`GIT ROOT=`), never in the host repo.
- **Tools bootstrap** is only `ninja`.
  The rest start on demand (`REQUIRE_TOOL` for extras).
  There is no `BUILDMASTER_INITIALIZE_EXTRA_TOOLS`.

### Fixed

- **Per-component `TOOLCHAIN` dump.**
  Nested configures load a component toolchain file built from the parent registry: `BUILDMASTER_INSTALL_*`, template dirs (`BUILDMASTER_TOOLS_CMAKE_SRCDIR`, …) and `ENV_*` stay unified with the parent; only compilers/binutils are overridden.
  A toolchain override no longer bootstraps a second install tree under the component build dir.
  Incomplete snapshots (missing tool `*_SRCDIR` / `ENV_*`) no longer die with `File /templates/configure.cmake.in does not exist` when a nested project creates further components.
  Harness fixture `tc-prefix` locks the dump.
- **Nested `add_subdirectory(buildmaster)` no longer corrupts the shared `toolchain.cmake`.**
  When `BUILDMASTER_CONFIGURED` is already TRUE (host loaded the parent dump as `CMAKE_TOOLCHAIN_FILE`), the root `CMakeLists.txt` loads helpers, propagates vars, and returns — without `toolchain_reset` / module re-export / `toolchain_write`.
  Nested BM keeps `BUILDMASTER_ROOT`, `BUILDMASTER_INSTALL_DIR` and `BUILDMASTER_CONFIGURED`.
- **Meson nested setups with system `ld`** no longer pass `-fuse-ld=/usr/bin/ld` (or other absolute linker paths) into `c_link_args` / `cpp_link_args`.
- **`clang-cl` + inherited MSVC LTCG flags.**
  When the parent job uses `clang-cl` (or a stage selects `TOOLCHAIN=clang-cl`), stages strip `/GL` and `/LTCG*` from C/CXX and linker flags instead of forwarding them.
  The translator is the single place that puts profile IPO back (`-flto` or `/GL`+`/LTCG`).
- **Meson on Windows (MSVC-like toolchains)** does **not** inject `/std:c11` into nested Meson `c_args`.
- **Meson stages: `SCCACHE_DIR` path normalization** no longer writes into `CCACHE_DIR`.
- **Dependant configure targets under Ninja.**
  Long configures no longer look hung; each dependant configure sets `USES_TERMINAL` and a clear `COMMENT`.
  On Windows + Ninja the redundant `cmake -E echo` that concatenated `Configuring x` twice is gone.
- **Git operations never run in the host repository.**
  A work tree equal to `CMAKE_SOURCE_DIR`, or a `ROOT=` / `SOURCE=` path that escapes the component `srcdir`, is FATAL before the tree is probed.
- **Fragment GLOBAL `BUILDMASTER_COMPONENT_<id>_NAMES` / `_FILES`.**
  Sealed after `write_fragment` so REPACK / meta merge see the produced archives.
- **REPACK + `NOINSTALL` members** wait `<id>_install` (oficios on the BUILDDIR), not `<id>_build`, so variant stems (`*-static`) are renamed before merge.
  Merge `CMAKE_AR` is the publisher `TOOLCHAIN=` archiver, not the parent `CMAKE_AR`.
- **`STRIPRES` uses the component archiver.**
  A `msvc` leaf built with `lib.exe` no longer lists/removes members with the parent’s `llvm-lib` (or the reverse) and warns `no such file or directory` for a name `/LIST` had just printed.
- **Toolchain triples are mandatory.**
  Linux `gcc` is binutils `ar` + `-fuse-ld=bfd`.
  Darwin `gcc` is Homebrew `gcc-N` + cctools `ar`/`ld` (no `CMAKE_LINKER_TYPE=BFD`, no `-fuse-ld=bfd`; Apple CMake rejects `LINKER_TYPE 'BFD'`).
  Linux `clang` is `llvm-ar` + `-fuse-ld=lld`.
  Darwin `clang` is cctools `ar` + `ld`.
  `clang-cl` is `llvm-lib` + `lld-link` + `-fuse-ld=lld` on C/CXX and LD (Meson sanity ignores the flag after `/link`).
  `msvc` is `lib.exe` + `link.exe`.
  A missing tool of *that* triple is FATAL.
  Linux `gcc`/`clang` get `-fuse-ld=` on LD only (`cc -c -Werror=unused-command-line-argument`).
  Darwin gcc/clang get none (ld64).
- **`-fuse-ld=` placement.**
  `clang-cl`: on C/CXX and LD (Meson sanity is `clang-cl <c_args> /link <c_link_args>`; the driver ignores the flag after `/link`).
  Linux `gcc` / `clang`: LD only (`cc -c -Werror=unused-command-line-argument` + fuse-ld on C made dav1d report “Atomics not supported”).
  Darwin `gcc` / `clang`: no `-fuse-ld` (ld64).
  Harness checks all four.
- **Darwin `IPO=fat`.**
  `-ffat-lto-objects` is not passed on Apple (AppleClang rejects it; nested try_compile died).
  Fat becomes `on`.
  One STATUS per configure.

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
- Incomplete component toolchain snapshots (missing tool `*_SRCDIR` / `ENV_*`) that led to failures such as `File /templates/configure.cmake.in does not exist` when nested projects created further components
- **Nested `add_subdirectory(buildmaster)` no longer corrupts the shared `toolchain.cmake`:** when `BUILDMASTER_CONFIGURED` is already TRUE (host loaded the parent dump as `CMAKE_TOOLCHAIN_FILE`), the root `CMakeLists.txt` loads helpers, propagates vars, and returns—without `toolchain_reset` / module re-export / `toolchain_write`. Previously a nested bootstrap cleared the registry, re-wrote only root-level keys, and overwrote the parent dump, which then broke deeper components with empty template roots (`/templates/configure.cmake.in`, `/component_shared.cmake.in`)
- **Meson nested setups with system `ld`:** no longer pass `-fuse-ld=/usr/bin/ld` (or other absolute linker paths) into `c_link_args` / `cpp_link_args`. GCC rejects path-form `-fuse-ld=`; `buildmaster_fuse_ld_flag()` only emits driver flavor names, so PostgreSQL and other Meson components configure correctly under a default Linux linker
- **clang-cl + inherited MSVC LTCG flags:** when the parent job uses clang-cl (or a stage selects `TOOLCHAIN clang-cl`), `create_cmake_stages` / `create_meson_stages` strip `/GL` and `/LTCG*` from C/CXX and linker flags instead of forwarding them. clang-cl was warning `unknown argument ignored` for `/GL`; IPO remains driven by `CMAKE_INTERPROCEDURAL_OPTIMIZATION_*` and Meson `b_lto`, not by those MSVC-only switches
- **Meson on Windows (MSVC-like toolchains):** do **not** inject `/std:c11` into nested Meson `c_args`. That flag did not fix clang-cl PostgreSQL C99 probes (UCRT `complex`/`tgmath` vs Clang `_Complex`) and could break real `cl` builds (e.g. Postgres `VA_ARGS_NARGS_` / non-constant initializers). Prefer `TOOLCHAIN msvc` for PostgreSQL on Windows. Upstream projects set their own C standard; only `/Z7` is still appended for CodeView on MSVC-like drivers
- Meson stages: `SCCACHE_DIR` path normalization wrote into `CCACHE_DIR` instead of `SCCACHE_DIR`, so sccache cache directories could be lost or overwrite the ccache path during nested Meson setup
- Dependant configure targets (`component_*_dependant.cmake.in`): under the **Ninja** generator, long configures (e.g. FFmpeg `meson setup`) looked hung — the silent env runner swallowed `message(STATUS)` from the configure `-P` script. Makefiles still printed progress. Now each dependant configure target sets `USES_TERMINAL` and a clear `COMMENT "Configuring <component>"` so Ninja shows the step as soon as it starts
- Dependant configure progress on **Windows + Ninja**: `cmake -E echo "Configuring …"` plus the same `COMMENT` concatenated on one line (`Configuring x265Configuring x265`). Dropped the redundant `echo`; a single `COMMENT` is enough
- Dependant components: `indent_level` is forced to `0` in `create_component` when a dependency is set. Hierarchical tabs are only meaningful in the parent **configure** log (`message_indented`); dependant stages run at **build** time and must not inherit plugin-level indentation in status lines or nested stage scripts
- **Component `TOOLCHAIN=` dump is the trunk toolchain plus a compiler overlay.**
  Nested `add_subdirectory(buildmaster)` keeps `BUILDMASTER_ROOT`,
  `BUILDMASTER_INSTALL_DIR` and `BUILDMASTER_CONFIGURED`. A component
  override no longer bootstraps a second install tree under the
  component build dir. Harness fixture `tc-prefix` locks the dump.

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
