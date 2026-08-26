# BuildMaster self-tests

Synthetic harness with **no real third-party projects**. It catches:

- missing or renamed public commands
- broken variable propagation / toolchain exports
- broken `*_dependant` graph edges (`add_dependencies`)
- regressions in configure → build → install for tiny CMake components

Run this harness after changing the DSL **before** validating a large consumer
superbuild.

## Layout

| Path | Role |
|------|------|
| `tests/expected/` | **Contract lists** — edit these when extending coverage |
| `tests/harness/` | Host `CMakeLists.txt` and checkers (change only when adding a new *kind* of check) |
| `tests/harness/fixtures/` | Tiny CMake projects used as synthetic components |
| `.github/workflows/ci.yml` | Runs the harness only; does not hardcode expected values |

## Local run

```bash
rm -rf build/harness
cmake -S tests/harness -B build/harness -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/harness --target run_buildmaster_checks   # contract (mostly configure-time)
cmake --build build/harness --target run_buildmaster_smoke    # build + install + artifacts
```

`run_buildmaster_smoke` already depends on the install stages; it is enough for a
full local check.

## What to update when you change the DSL

Do **not** put new assertions in the workflow YAML. Prefer lists under
`tests/expected/`.

| You changed… | Update | Also |
|--------------|--------|------|
| New public `function()` / `macro()` | `expected/public_functions.txt` | One name per line |
| Removed or renamed public command | Same file (remove / rename) | Grep the tree so the name still exists |
| New propagated or toolchain-exported variable | `expected/propagated_vars.txt` | Choose policy/platform (see below) |
| Variable is defined but path is created lazily | Prefer policy `required` over `file` | Or `file(MAKE_DIRECTORY)` in the DSL |
| New `*_dependant` wiring | `expected/dependant_edges.txt` | Wire components in `harness/CMakeLists.txt` if needed |
| New install artifact to verify | `expected/smoke_artifacts.txt` | Path relative to `BUILDMASTER_INSTALL_DIR` |
| New install stage name to build | `expected/smoke_targets.txt` | And `DEPENDS` on `run_buildmaster_smoke` if required |
| New component shape (e.g. Meson fixture) | `harness/fixtures/` + harness `CMakeLists.txt` | Then edges / artifacts as above |

### Checklist for a typical new feature

1. Implement the feature in the DSL.
2. If it exposes a new command → add the name to `public_functions.txt`.
3. If it exports a new variable → add a line to `propagated_vars.txt`.
4. If it affects dependant ordering → add `A -> B` to `dependant_edges.txt` and
   ensure the harness creates those targets.
5. If it affects install outputs → extend fixtures if needed, then
   `smoke_artifacts.txt`.
6. Run the local commands above until configure and smoke succeed.
7. Push; CI runs the same smoke target via `build-with-toolchain`.

## Contract file formats

### `public_functions.txt`

- One command name per line.
- Lines starting with `#` and blank lines are ignored.
- Names must match `function(name` / `macro(name` available after
  `add_subdirectory(BuildMaster)` + `include(helpers.cmake)`.

### `propagated_vars.txt`

```text
VAR_NAME|policy|platform
```

| policy | Meaning |
|--------|---------|
| `required` | Defined and non-empty |
| `defined` | Defined (empty allowed) |
| `file` | Defined, non-empty, **and** the path exists at configure time |

| platform | Meaning |
|----------|---------|
| `all` | Every OS |
| `windows` | WIN32 only |
| `unix` | Non-WIN32 only |

### `dependant_edges.txt`

```text
dependent_target -> prerequisite_target
```

Checked with `MANUALLY_ADDED_DEPENDENCIES` after component fragments are
`include()`d. Example:

```text
dep_configure -> base_install
dep -> dep_install
```

### `smoke_artifacts.txt`

```text
relative/path|platform
```

Paths are relative to `BUILDMASTER_INSTALL_DIR`. Use `lib/…` on Unix only if the
harness forces a stable `CMAKE_INSTALL_LIBDIR` (see harness host); otherwise
match the real layout (`lib`, `lib64`, …).

### `smoke_targets.txt`

Optional documentation of install stage names; the harness currently lists
smoke dependencies explicitly on `run_buildmaster_smoke`.

## Harness conventions (avoid target clashes)

- **Component id** (INTERFACE target, stage names `*_configure` / `*_build` /
  `*_install`) must **not** equal an **imported subcomponent** name.
  - Good: component `base`, subcomponent `baselib`.
  - Bad: component `base`, subcomponent `base` (duplicate `add_library` name).
- Fixtures are ordinary CMake projects (`STATIC`, `GNUInstallDirs`, install
  rules). They are the “final libraries”; BuildMaster does not inject
  `GNUInstallDirs` for them.
- The harness host should `include(GNUInstallDirs)` before
  `add_subdirectory(BuildMaster)` so `BUILDMASTER_INSTALL_*` matches fixture
  installs. For stable CI paths, the host may force
  `CMAKE_INSTALL_LIBDIR=lib`.

## Checkers (rarely edited)

| File | When it runs | Fails if |
|------|--------------|----------|
| `check_api.cmake` | Configure | A listed command is not a CMake `COMMAND` |
| `check_propagation.cmake` | Configure | A listed variable fails its policy |
| `check_dependant_edges.cmake` | Configure | Edge missing or targets absent |
| `check_smoke_artifacts.cmake` | After smoke install (`-P`) | Expected file missing under install prefix |

If a new *class* of check is needed (not just another line in a list), add a
checker under `tests/harness/` and `include()` it from the harness
`CMakeLists.txt`, still driven by data under `tests/expected/` when possible.
