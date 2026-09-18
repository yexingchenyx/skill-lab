---
name: cpp-create-project
description: Create a new C++ project with CMake build system, modular src layout, Google Test (default), and CLI11
---

# Create C++ Project

Create a new C++ project with CMake build system, modular src layout,
Google Test (enabled by default), and CLI11 for command-line parsing
(always included).

## When to use
- User asks to create a new C++ project
- User asks to scaffold or initialize a C++ codebase

## Inputs to ask user (if not specified)
- Project name (required)
- C++ standard (default: C++20)
- Include tests? (default: **yes, Google Test**)

## Placeholders

All templates in `templates/` use these placeholders — replace every occurrence:

| Placeholder     | Example (project `myapp`) |
|-----------------|---------------------------|
| `<project-name>`| `myapp`                   |
| `<project-name-dashed>` | `my-app` (underscores → dashes; used in `vcpkg.json` name) |
| `<PROJECT_NAME_UPPER>` | `MYAPP`            |
| `<cxx-standard>`| `20`                      |
| `<namespace-macro>` | `MYAPP` (expands to the config.h namespace macro, used in `namespace X::...` declarations) |

### Placeholder replacement safety (by design)

A **plain literal replacement of the placeholders above can never break
anything**: every `@...@` token in `cmake/config.h.in` is a CMake
`configure_file` variable with a **fixed name containing no placeholders**
(`@PROJECT_VERSION@`, `@PROJECT_NAMESPACE@`, `@PROJECT_DEBUG@`,
`@PROJECT_GIT_COMMIT@`, `@PROJECT_BUILD_TIME@`) — do not rename these or
embed placeholders inside `@...@`. Source files reference the namespace via
`<namespace-macro>_NS` (replaced with `<PROJECT_NAME_UPPER>` at
instantiation); only `#include` paths use the concrete `<project-name>`.

## Built-in conventions (already in the templates — do not re-implement)

- **vcpkg (default ON)**: the `CMakePresets.json` "base" preset sets
  `CPP_PJ_USE_VCPKG=ON` and `CPP_PJ_VCPKG_ROOT` (no `toolchainFile` in the
  preset). The top-level `CMakeLists.txt` includes `cmake/options.cmake`
  **before `project()`**, and `options.cmake` sets `CMAKE_TOOLCHAIN_FILE`
  from `<PROJECT_NAME_UPPER>_VCPKG_ROOT` — the toolchain must be active
  before the first `project()` call, which is why the include order matters.
- **`vcpkg.json` manifest**: lists default deps (`cli11`, `gtest >= 1.14.0`);
  vcpkg installs them into `vcpkg_installed/<triplet>/` at the project root
  (`VCPKG_INSTALLED_DIR` set in the base preset — outside `build/` so
  installs survive `rm -rf build` and are shared across presets). Keep in
  sync when adding libraries via `cpp-add-thirdparty`.
- **`vcpkg-configuration.json`**: pins the version baseline (lockfile for
  reproducible dependency versions). Obtain the baseline with
  `git -C <vcpkg-root> rev-parse HEAD` at generation time (fall back to the
  latest known commit if no local vcpkg exists).
- **Third-party local-first**: each `cmake/thirdparty/<lib>.cmake` tries
  `find_package(<lib> QUIET)` first, falls back to `FetchContent` only when
  not found, then prints a final STATUS summary with the version and
  location actually used (FetchContent-built libraries report "built from
  source (FetchContent)" since `LOCATION` is unavailable). Every dependency
  must expose a namespaced target (`<lib>::<lib>`); never leak include
  dirs/definitions globally. Full rules: `templates/thirdparty-README.md.tmpl`.
- **Dynamic vs static via presets**: `BUILD_SHARED_LIBS=ON` is set in the
  `CMakePresets.json` "base" preset (dynamic by default); `release-static`
  / `debug-static` presets set it to `OFF` for static builds. Module
  CMakeLists use a plain `add_library(...)` (no hardcoded `SHARED`) and
  gate `<PROJECT_NAME_UPPER>_STATIC_DEFINE` on `BUILD_SHARED_LIBS`, so the
  switch requires no source/CMakeLists edits.
- **Unified export macro**: all modules share a single
  `<PROJECT_NAME_UPPER>_API` macro defined in the generated `config.h`
  (dllexport/dllimport on Windows, visibility on GCC/Clang; expands to
  nothing for static builds via `<PROJECT_NAME_UPPER>_STATIC_DEFINE`).
  Each module defines `<PROJECT_NAME_UPPER>_EXPORTS` (PRIVATE) while
  building itself. Public headers just include `config.h` and mark public
  classes/functions with `<PROJECT_NAME_UPPER>_API` — no per-module export
  headers, and new modules need no config.h change.

## Steps

1. Create the directory structure:

```
<project-name>/
├── CMakeLists.txt
├── CMakePresets.json               # presets: release, debug, release-static, debug-static
├── vcpkg.json                      # vcpkg manifest (default deps: cli11, gtest)
├── vcpkg-configuration.json        # pins the baseline commit (dependency lockfile)
├── README.md
├── .gitignore
├── cmake/                          # CMake modules
│   ├── options.cmake               # build options + vcpkg toolchain (included BEFORE project())
│   ├── common.cmake                # output dirs, git commit, build time, config.h generation
│   ├── config.h.in                 # template for the generated config header (incl. <PRJ>_API)
│   ├── thirdparty.cmake            # third-party loading entry point
│   └── thirdparty/                 # one config file per third-party library
│       ├── README.md               # how to add a third-party dependency
│       ├── cli11.cmake             # CLI11 command-line parsing (always)
│       └── googletest.cmake        (always — GTest is the default test framework)
├── src/                            # one self-contained directory per module
│   ├── core/                       # target <project>_core (lib type via BUILD_SHARED_LIBS)
│   │   ├── CMakeLists.txt
│   │   ├── include/<project-name>/core/foo.hpp
│   │   └── src/foo.cpp
│   └── algorithm/                  # links core, target <project>_algorithm
│       ├── CMakeLists.txt
│       ├── include/<project-name>/algorithm/foo.hpp
│       └── src/foo.cpp
├── cli/                            # CLI tools
│   ├── CMakeLists.txt              # add_subdirectory(common) + one per tool
│   ├── common/                     # static lib cli_common (CLI11 + aggregate lib)
│   │   ├── CMakeLists.txt
│   │   ├── include/<project-name>/cli/util.hpp
│   │   └── src/util.cpp
│   └── foo/                        # demo CLI tool <project>_cli_foo
│       ├── CMakeLists.txt
│       └── main.cpp
└── tests/                          # tests, one subdirectory per module
    ├── CMakeLists.txt              # add_subdirectory(common) first, then per module
    ├── common/                     # static lib test_common (fixtures/helpers)
    │   ├── CMakeLists.txt
    │   ├── include/<project-name>/tests/util.hpp
    │   └── src/util.cpp
    ├── core/                       # test target <project>_core_tests
    │   ├── CMakeLists.txt
    │   └── foo_test.cpp
    └── algorithm/                  # test target <project>_algorithm_tests
        ├── CMakeLists.txt
        └── foo_test.cpp
```

### Module layout convention

- Default modules: `core` and `algorithm`; `algorithm` depends on `core`
  (its header includes `foo.hpp` and its code uses `core::Greeter`).
- Each module is self-contained under `src/<module-name>/`: its own
  `CMakeLists.txt` (defines target `<project-name>_<module-name>` plus a
  namespaced ALIAS `<project-name>::<module-name>`, globs `src/*.cpp`,
  publishes `include/` and the generated config dir via
  `target_include_directories(... PUBLIC ...)`), its headers in
  `src/<module-name>/include/<project-name>/<module-name>/` and its
  implementation in `src/<module-name>/src/`.
- Module dependencies are expressed with `target_link_libraries` inside the
  module's own CMakeLists.txt using the namespaced alias (e.g. `algorithm`
  links `<project-name>::core` PUBLIC).
- The top-level `CMakeLists.txt` adds each module via `add_subdirectory` and
  defines an INTERFACE aggregate target `${PROJECT_NAME}_lib` (ALIAS
  `<project-name>::<project-name>_lib`) linking all modules via their
  namespaced aliases, plus the generated config header include dir; the app
  and tests link against `${PROJECT_NAME}_lib`.
- Each module's tests live in `tests/<module-name>/` (one test file per
  module); `tests/common/` is a shared test-utilities **static library**
  (`test_common`) that must be added via `add_subdirectory(common)`
  **before** the module test subdirectories in `tests/CMakeLists.txt`.
- `cli/common/` holds a shared CLI-utilities **static library** target
  `cli_common` (alias `<project-name>::cli_common`): links `CLI11::CLI11`
  and `${PROJECT_NAME}::${PROJECT_NAME}_lib` PUBLIC, added via
  `add_subdirectory(cli)` after the aggregate `_lib` target is defined.
  CLI executables link `<project-name>::cli_common`.
- `cli/foo/` is a demo CLI tool: executable target `<project-name>_cli_foo`
  linking `${PROJECT_NAME}::cli_common`. New CLI tools follow the same
  pattern (new `cli/<tool>/` dir + `add_subdirectory(<tool>)` in
  `cli/CMakeLists.txt`).
- Header path mirrors the module: `#include "<project-name>/<module-name>/<module-name>.hpp"`.
- Every module header includes the generated config header:
  `#include "<project-name>/config.h"`.
- Namespace: all modules use the unified namespace defined by
  `PROJECT_NAMESPACE` (default: the project name — set explicitly in the
  `CMakePresets.json` "base" preset and in `cmake/options.cmake`'s
  fallback; override with `-DPROJECT_NAMESPACE=...`).
- New module = new `src/<mod>/` dir (CMakeLists from
  `templates/module-CMakeLists.txt.tmpl` if no module dependencies, or
  `templates/module-deps-CMakeLists.txt.tmpl` if it depends on core) +
  `tests/<mod>/` dir; then add `add_subdirectory(<mod>)` in
  `src/CMakeLists.txt` and link it into `${PROJECT_NAME}_lib` in the
  top-level `CMakeLists.txt` (two lines).

2. Generate files from templates (copy and replace placeholders):

- `templates/CMakeLists.txt.tmpl` → `CMakeLists.txt`
- `templates/CMakePresets.json.tmpl` → `CMakePresets.json`
- `templates/vcpkg.json.tmpl` → `vcpkg.json` (replace `<project-name-dashed>`)
- `vcpkg-configuration.json` → project root (see built-in conventions above
  for the baseline; no template — content is project-independent apart from
  the baseline hash)
- `templates/src-CMakeLists.txt.tmpl` → `src/CMakeLists.txt`
- `templates/options.cmake.tmpl` → `cmake/options.cmake`
- `templates/common.cmake.tmpl` → `cmake/common.cmake`
- `templates/config.h.in.tmpl` → `cmake/config.h.in`
- `templates/thirdparty.cmake.tmpl` → `cmake/thirdparty.cmake`
- `templates/thirdparty-README.md.tmpl` → `cmake/thirdparty/README.md`
- `templates/thirdparty-googletest.cmake.tmpl` → `cmake/thirdparty/googletest.cmake`
- `templates/thirdparty-cli11.cmake.tmpl` → `cmake/thirdparty/cli11.cmake`
- `templates/gitignore.tmpl` → `.gitignore`
- `templates/README.md.tmpl` → `README.md`
- `templates/module-foo-header.hpp.tmpl` → `src/core/include/<project-name>/core/foo.hpp`
- `templates/module-foo-impl.cpp.tmpl` → `src/core/src/foo.cpp`
- `templates/module-CMakeLists.txt.tmpl` → `src/core/CMakeLists.txt` (replace `<module-name>` with `core`, `<MODULE_NAME_UPPER>` with `CORE`)
- `templates/module-algorithm-foo-header.hpp.tmpl` → `src/algorithm/include/<project-name>/algorithm/foo.hpp`
- `templates/module-algorithm-foo-impl.cpp.tmpl` → `src/algorithm/src/foo.cpp`
- `templates/module-deps-CMakeLists.txt.tmpl` → `src/algorithm/CMakeLists.txt` (replace `<module-name>` with `algorithm`, `<MODULE_NAME_UPPER>` with `ALGORITHM`; the core link is already wired in)
- `templates/cli-CMakeLists.txt.tmpl` → `cli/CMakeLists.txt`
- `templates/cli-common-CMakeLists.txt.tmpl` → `cli/common/CMakeLists.txt`
- `templates/cli-common-include/cli-util.hpp.tmpl` → `cli/common/include/<project-name>/cli/util.hpp`
- `templates/cli-common-src-util.cpp.tmpl` → `cli/common/src/util.cpp`
- `templates/cli-foo-CMakeLists.txt.tmpl` → `cli/foo/CMakeLists.txt`
- `templates/cli-foo-main.cpp.tmpl` → `cli/foo/main.cpp`

Feel free to adapt the sample `Greeter` (core) and `add`/`greet_sum`
(algorithm, which uses core) to the user's actual use case. Add more modules
if the user asks.

3. Tests (Google Test, on by default — skip only if the user explicitly
   declines):

- `templates/test-core-foo.cpp.tmpl` → `tests/core/foo_test.cpp`
- `templates/test-algorithm-foo.cpp.tmpl` → `tests/algorithm/foo_test.cpp`
- `templates/tests-CMakeLists.txt.tmpl` → `tests/CMakeLists.txt`
- `templates/test-common-CMakeLists.txt.tmpl` → `tests/common/CMakeLists.txt`
- `templates/test-common-include/tests-util.hpp.tmpl` → `tests/common/include/<project-name>/tests/util.hpp`
- `templates/test-common-src-util.cpp.tmpl` → `tests/common/src/util.cpp`
- `templates/test-module-CMakeLists.txt.tmpl` → `tests/core/CMakeLists.txt` (replace `<module-name>` with `core`, `<MODULE_NAME_UPPER>` with `CORE`)
- `templates/test-module-CMakeLists.txt.tmpl` → `tests/algorithm/CMakeLists.txt` (replace `<module-name>` with `algorithm`, `<MODULE_NAME_UPPER>` with `ALGORITHM`)

4. Do NOT initialize a git repository — the skill only generates project
   files. Git initialization/commits are left to the user.

5. Verify the project builds and tests pass (via the presets):

```bash
cmake --preset release && cmake --build --preset release && ctest --preset release
```

(Plain commands `cmake -B build && cmake --build build && ctest --test-dir build`
also work.)

Report the created structure and how to build/run.
