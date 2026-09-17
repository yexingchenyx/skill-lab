---
name: cpp-add-thirdparty
description: Add a third-party library to a C++ project created by cpp-create-project (namespaced target convention, find_package first with FetchContent fallback)
---

# Add Third-Party Library

Add a third-party dependency to an existing C++ project that was scaffolded
by the `cpp-create-project` skill (CMake, modular `src/<module>/` layout).

## When to use
- User asks to add a third-party library (e.g. fmt, re2, spdlog, abseil) to
  a project created by `cpp-create-project`
- User asks to wire a dependency into one or more modules

## Inputs to ask user (if not specified)
- Library name and version (required)
- Which module(s) should link it (optional — if not specified, the library
  is only made available as `<lib>::<lib>` and no module is modified)
- Link visibility: `PUBLIC` (default — simplest and keeps the dependency
  propagating to consumers of the module; downgrade to `PRIVATE` only if the
  user explicitly asks to minimize the dependency surface), or `INTERFACE`
  (header-only usage)
- Preferred acquisition: system `find_package` first (default), or force
  `FetchContent`

## Hard rules (from the project's cmake/thirdparty/README.md)

1. **Namespaced target only.** The library must be exposed as a namespaced
   interface-style target (`<lib>::<lib>`, e.g. `re2::re2`, `fmt::fmt`) so
   consumers link with `target_link_libraries(<target> PRIVATE re2::re2)`.
   If the library doesn't provide one, create it:
   ```cmake
   add_library(<lib>::<lib> ALIAS <lib>)
   # or for a raw found library:
   add_library(<lib>::<lib> INTERFACE IMPORTED)
   target_include_directories(<lib>::<lib> INTERFACE ${<LIB>_INCLUDE_DIRS})
   target_link_libraries(<lib>::<lib> INTERFACE ${<LIB>_LIBRARIES})
   ```
2. **Never leak globally.** Do not use `include_directories`,
   `add_definitions`, `link_directories`, or `link_libraries` — attach
   include dirs/definitions/libs to the namespaced target only.
3. **One file per library.** Each dependency lives in
   `cmake/thirdparty/<lib>.cmake`.
4. **Prefer `find_package`; fall back to `FetchContent`.** Pin an exact
   version/tag when using FetchContent.

## Steps

1. **Create `cmake/thirdparty/<lib>.cmake`** following the pattern of the
   existing `googletest.cmake`:

   ```cmake
   include(FetchContent)

   # <lib> as a namespaced target <lib>::<lib>
   # Loaded from cmake/thirdparty.cmake; link with:
   #   target_link_libraries(<target> PRIVATE <lib>::<lib>)

   find_package(<lib> <version> QUIET)
   if(NOT <lib>_FOUND)
     FetchContent_Declare(
       <lib>
       URL https://github.com/<org>/<lib>/archive/refs/tags/v<version>.zip
       DOWNLOAD_EXTRACT_TIMESTAMP TRUE
     )
     FetchContent_MakeAvailable(<lib>)
   endif()
   # If <lib> does not define <lib>::<lib> itself, alias it here:
   # add_library(<lib>::<lib> ALIAS <lib>)
   ```

   Notes:
   - If the library supports CMake find-module config files (`fmt`, `re2`,
     `spdlog`, ... do), keep the `find_package` attempt and pass version.
   - For FetchContent, prefer a release tag URL; use `GIT_REPOSITORY`+
     `GIT_TAG` only if no release archive exists.
   - If the upstream target name differs (e.g. `fmt` provides `fmt::fmt`
     already; `spdlog` provides `spdlog::spdlog`), alias only when needed.

2. **Register it in `cmake/thirdparty.cmake`**: add one line
   `include(<lib>)` (the file lives in `cmake/thirdparty/`, which is already
   on `CMAKE_MODULE_PATH`). Optionally guard with an option if the library
   is optional, e.g.:
   ```cmake
   include(<lib>)  # provides <lib>::<lib>
   ```
   Remove the corresponding commented example line if present.

3. **Link it into the consuming module** (only when the user specified
   which module(s) should use the library — otherwise skip this step; the
   library is just made available as `<lib>::<lib>`): edit
   `src/<module>/CMakeLists.txt` and add:
   ```cmake
   target_link_libraries(${PROJECT_NAME}_<module> PUBLIC <lib>::<lib>)
   ```
   `PUBLIC` is the default. Use `PRIVATE` only if the user explicitly asks
   to minimize the dependency surface; use `INTERFACE` for header-only
   usage. Never link at the top level "for convenience".

4. **Verify** — configure, build, and run tests:
   ```bash
   cmake --preset release && cmake --build --preset release && ctest --preset release
   ```
   Do NOT modify existing source files or add new test code — the skill only
   wires up the dependency.

5. **Update `cmake/thirdparty/README.md`** only if you had to deviate from
   the convention (e.g. created a wrapper target) — document the deviation
   there.

## Example: adding fmt to the core module

- `cmake/thirdparty/fmt.cmake`: find_package(9.1.0) → FetchContent fallback
  to `fmtlib/fmt` v10.2.1; `fmt` already exports `fmt::fmt`.
- `cmake/thirdparty.cmake`: add `include(fmt)`.
- `src/core/CMakeLists.txt`:
  `target_link_libraries(${PROJECT_NAME}_core PUBLIC fmt::fmt)`.

Report: which files were created/modified, how the library is linked, and
the build/test verification result.
