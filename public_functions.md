@page public_functions "Public functions"

@section uf_overview Overview

BuildMaster’s public surface is **ten commands**. Everything else
is internal. How to declare a tree, every optstr key, and full
examples: [README.md](README.md).

The harness list is `.github/tests/expected/public_functions.txt`.

| Command | Role |
|---------|------|
| `buildmaster_component(id title srcdir options mode produced [optstr])` | One node. Backend from `srcdir`. Mode: `static`, `shared`, `headers`, or `executable`. No builddir argument |
| `buildmaster_depend(source dest)` | Order-only edge |
| `buildmaster_link(source dest [dest…])` | `INTERFACE` link; also a depend edge when `dest` is a graph node |
| `buildmaster_meta(id title [, optstr])` | `INTERFACE` collection. `REPACK` merges static members |
| `buildmaster_meta_add(meta member…)` | Membership (allowed before `buildmaster_meta`) |
| `buildmaster_group(id [title])` | Configure outline only. Not a graph node |
| `buildmaster_group_add(group member…)` | Outline membership |
| `buildmaster_hook_component(id fn alias [CAPTURE …])` | Runs after that id materializes |
| `buildmaster_hook_graph(fn alias [CAPTURE …])` | Runs after the whole graph materializes |
| `buildmaster_message(level text [, indent])` | Log. Module is always `USER` |

Do not call `_bm_*` from a consumer. Do not `add_dependencies()`
on `<id>_configure` / `_build` / `_install`; use
`buildmaster_depend` / `buildmaster_link`.

@section uf_component buildmaster_component

```cmake
buildmaster_component(
	foo
	"Foo library"
	"${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/foo"
	""
	static
	"foo"
	"NOINSTALL;RENAME"
)
```

Arity is fixed: `id title srcdir options mode produced [optstr]`.
`options` is a CMake list of `KEY=value` for the nested configure
(or empty). `produced` is the install stem (library or executable).
`optstr` is optional.

Known optstr keys (flags may omit `=`): `TOOLCHAIN`, `RENAME`,
`NOINSTALL`, `WHOLE`, `STRIPRES`, `REPACK`, `PC={…}`, `LINK=`,
`LINKFLAGS=`, `GIT={…}`, `FILES={…}`, `REQUIRE_TOOL=`, `ALIAS=`,
`BACKEND=`, `SOURCE=`. `INDENT=` is ignored (use
`buildmaster_group`). `BUILDONLY` is rejected.

Semantics of each key: [README.md](README.md).

@section uf_depend_link depend / link

```cmake
buildmaster_depend(consumer foo)
buildmaster_link(consumer foo bar)
```

`depend` waits. `link` waits and records `INTERFACE` linkage when
`dest` is a BM id, alias, library spec, target, or archive.
Several dests on one `link` call are allowed.

@section uf_meta Meta

```cmake
buildmaster_meta(bundle "Bundle" "REPACK")
buildmaster_meta_add(bundle leaf_a leaf_b)
```

A meta is not a backend. `REPACK` folds static members into one
prefix archive named after the meta id. `NOINSTALL` members still
run oficios before the merge.

@section uf_group Groups

```cmake
buildmaster_group(codecs "Codecs")
buildmaster_group_add(codecs opus vorbis)
```

Indent of configure banners only. No targets, no edges, no install.

@section uf_hooks Hooks

```cmake
buildmaster_hook_component(foo my_fn after_foo)
buildmaster_hook_graph(my_graph after_all)
```

`fn` must exist at registration. `alias` is the order key (ASCII).
`CAPTURE` snapshots variables by copy. A hook is not an edge.

@section uf_log Logging

```cmake
buildmaster_message(STATUS "Setting up Foo" 1)
```

Levels: `LOWLEVEL`, `DEBUG`, `INFO`, `STATUS`, `WARNING`, `FATAL`.
Filter: `BUILDMASTER_LOGLEVEL`. `WARNING` and `FATAL` are never
filtered. `BUILDMASTER_LOG_NOCOLOR` disables ANSI.
