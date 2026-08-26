# BuildMaster — TODO

Open work toward **1.1.0**. Keep this list short; move finished items into `CHANGELOG.md` and delete them here.

---

## 1. Deferred dependency resolution (order-independent graph)

**Goal:** Component declaration order must not matter. Dependencies are registered first and **wired only at the end** of the parent configure (or via an explicit “finalize” step), with clear errors for missing names and cycles.

**Why:**
- Today the graph depends on include/`create_*` order and on string targets such as `Foo_install`. Easy to get wrong in large trees (FFmpeg plugins, DB clients, StormByte chains).
- Failures often show up late (link/configure of the wrong component) instead of at registration time.

**Direction:**
- Phase A: every `create_*` only **registers** identity, stages, outputs, and declared dependency *names*.
- Phase B: a single finalizer resolves names → real targets, `add_dependencies`, and validates the graph.
- Error examples to aim for:
  - `PostgreSQL` depends on `OpenSSL_install`, but no component registered that install target.
  - Dependency cycle: `A → B → A`.

**Done when:**
- Two components can be declared in either order and still build the same graph.
- Unknown dependency names and cycles fail at configure with an explicit message.
- Existing callers that already declare in the “right” order keep working (backward compatible).

**Notes:** Do not conflate this with submodule pin order of BuildMaster itself; this is only the **component DSL** graph inside one parent project.

---

## 2. Nested configure log indentation

**Goal:** When components (or nested hosts) configure in a hierarchy, status lines show depth so CI logs stay readable—e.g. one extra indent level per nesting of *component configure*, not per accidental `add_subdirectory(buildmaster)`.

**Why:**
- Nested Buffer → Logger → Base (and similar) currently look flat; it is hard to see which line belongs to which component.
- Dependant stages already force `indent_level = 0` so they do not inherit plugin tabs; that is correct for *build-time* targets. This item is about **parent configure STATUS** hierarchy only.

**Direction:**
- Stable `+1` indent per logical configure nesting.
- Do not reintroduce Ninja double-echo (`Configuring x265Configuring x265`).
- Nested BuildMaster bootstrap that hits `BUILDMASTER_CONFIGURED` and returns early should not spam indented “Bootstrapping…” lines.

**Done when:**
- A multi-level StormByte (or similar) configure log shows clear parent/child grouping without breaking dependant `COMMENT` / `USES_TERMINAL` behaviour.

**Priority:** DX only; safe to do as a small change after or alongside (1).

---

## 3. Parent-owned helpers for nested BuildMaster (pin version irrelevant)

**Goal:** Recursive/nested `add_subdirectory(buildmaster)` must **not** depend on the submodule commit of the child repo for the *API* (validate toolchain, `create_*`, clean/fuse_ld, registry). Helpers and known profiles always come from the **root** bootstrap; nested copies only reuse already-loaded functions and parent paths (`BUILDMASTER_*`, install tree, generated scripts).

**Why:**
- Divergent pins (buffer vs logger vs crypto) caused missing commands (`propagate_all_vars_extra_tools`), incomplete `toolchain.cmake`, and “works in one repo, fails in the chain” CI.
- The nested `BUILDMASTER_CONFIGURED` guard already avoids rewriting the dump; the next step is making **helper loading** equally single-sourced.

**Direction (sketch):**
- Root sets something like `BUILDMASTER_HELPERS_LOADED` / path to the canonical helpers once.
- Nested bootstrap: if parent API is already loaded, skip re-including a possibly older `helpers.cmake` from the child’s submodule; still propagate vars / install paths as today.
- Document: “embedded in a parent tree, effective BM behaviour = root’s version; child submodule pin matters mainly when building that repo standalone.”

**Done when:**
- Parent on 1.1.x + child submodule still on older 1.0.x does not break nested configure solely because the child tree’s BM is behind (within a documented compatibility window).
- No second incomplete toolchain write; no “Unknown CMake command” from a stale nested helpers set.

**Notes:** Still need a clear policy if the **parent** is *older* than the child (unsupported or warn). Version the public DSL deliberately when macros change.

---

## Release plan

| Version | Content |
|---------|---------|
| **1.0.1** | Current fixes (toolchain, nested install, fuse-ld, clang-cl `/GL`, Meson `/std:c11`, …) — released / releasing now |
| **1.1.0** | Items **1**, **2**, and **3** above |

Do not park unrelated ideas here; open a short issue or a new section only if it is required for 1.1.0.