---
name: create-cpp-project
description: Create a new C++ project with CMake build system, modular src layout, and Google Test (default)
---

# Create C++ Project

Create a new C++ project with CMake build system, modular src layout, and
Google Test (enabled by default).

## When to use
- User asks to create a new C++ project
- User asks to scaffold or initialize a C++ codebase

## Inputs to ask user (if not specified)
- Project name (required)
- C++ standard (default: C++17)
- Include tests? (default: **yes, Google Test**)
- Build system (default: CMake; alternative: plain Makefile)

## Placeholders

All templates in `templates/` use these placeholders — replace every occurrence:

| Placeholder     | Example (project `myapp`) |
|-----------------|---------------------------|
| `<project-name>`| `myapp`                   |
| `<ProjectName>` | `MyApp`                   |
| `<PROJECT_NAME_UPPER>` | `MYAPP`            |
| `<cxx-standard>`| `20`                      |
| `<namespace-macro>` | `MYAPP` (expands to the config.h namespace macro, used in `namespace X::...` declarations) |

### Placeholder replacement safety (by design)

The templates are constructed so that a **plain literal replacement of the
placeholders above can never break anything**:

- Every `@...@` token in `cmake/config.h.in` is a CMake `configure_file`
  variable with a **fixed name containing no placeholders**
  (`@PROJECT_VERSION@`, `@PROJECT_NAMESPACE@`, `@PROJECT_DEBUG@`,
  `@PROJECT_GIT_COMMIT@`, `@PROJECT_BUILD_TIME@`). Placeholder replacement
  therefore cannot touch them. Do not rename these variables or embed
  placeholders inside `@...@`.
- Source files reference the namespace via `<namespace-macro>` (replaced with
  `<PROJECT_NAME_UPPER>` at instantiation, which expands to the config.h
  macro, e.g. `MYAPP`), and `#include` paths always use the concrete
  `<project-name>` (e.g. `#include "myapp/core/foo.hpp"`).
- Module CMakeLists come in two ready-to-use variants — no manual
  uncommenting is ever needed:
  - `templates/module-CMakeLists.txt.tmpl`: module with **no** module
    dependencies (use for `core`).
  - `templates/module-deps-CMakeLists.txt.tmpl`: module that **links
    `${PROJECT_NAME}::core` PUBLIC** (use for `algorithm` and any other
    module that includes core headers).

## Third-party library convention

Every third-party dependency in `cmake/thirdparty/<lib>.cmake` **must** expose
a namespaced interface-style target (e.g. `re2::re2`, `fmt::fmt`) so consumers
can link directly with `target_link_libraries(<target> PRIVATE re2::re2)`.

- Prefer `find_package`; fall back to `FetchContent`.
- If the library doesn't provide a namespaced target, create one via
  `add_library(<lib>::<lib> ALIAS ...)` or an `INTERFACE IMPORTED` target
  carrying its include dirs and libraries.
- Never leak include dirs/definitions globally — attach them to the target.
- Full rules are in `templates/thirdparty-README.md.tmpl` (generated as
  `cmake/thirdparty/README.md`); follow them when adding new libraries.

## Steps

1. Create the directory structure:

```
<project-name>/
├── CMakeLists.txt
├── CMakePresets.json               # configure/build/test presets (release, debug)
├── README.md
├── .gitignore
├── cmake/                          # CMake modules
│   ├── options.cmake               # build options / configuration
│   ├── common.cmake                # output dirs, git commit, build time, config.h generation
│   ├── config.h.in                 # template for the generated config header
│   ├── thirdparty.cmake            # third-party loading entry point
│   └── thirdparty/                 # one config file per third-party library
│       ├── README.md               # how to add a third-party dependency
│       └── googletest.cmake        (always — GTest is the default test framework)
├── src/                            # one self-contained directory per module
│   ├── core/
│   │   ├── CMakeLists.txt          # module build script (target <project>_core)
│   │   ├── include/
│   │   │   └── <project-name>/
│   │   │       └── core/
│   │   │           └── foo.hpp
│   │   └── src/
│   │       └── foo.cpp
│   ├── algorithm/
│   │   ├── CMakeLists.txt          # module build script (target <project>_algorithm)
│   │   ├── include/
│   │   │   └── <project-name>/
│   │   │       └── algorithm/
│   │   │           └── foo.hpp
│   │   └── src/
│   │       └── foo.cpp
│   └── main.cpp
└── tests/                          # tests, one subdirectory per module
    ├── CMakeLists.txt              # enable_testing + add_subdirectory per module
    ├── core/
    │   ├── CMakeLists.txt          # test target <project>_core_tests
    │   └── foo_test.cpp
    └── algorithm/
        ├── CMakeLists.txt          # test target <project>_algorithm_tests
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
  module, e.g. `tests/core/foo_test.cpp`). The top-level `CMakeLists.txt`
  calls `enable_testing()` (inside the BUILD_TESTS if-block, so the build
  root gets a CTestTestfile.cmake and `ctest --test-dir build` works);
  `tests/CMakeLists.txt` adds each module's tests via `add_subdirectory`;
  each `tests/<module-name>/CMakeLists.txt` defines a test target
  `<project-name>_<module-name>_tests` (globbing `*.cpp`, linking
  `${PROJECT_NAME}_lib` and `GTest::gtest_main`, discovered via
  `gtest_discover_tests`).
- Header path mirrors the module: `#include "<project-name>/<module-name>/<module-name>.hpp"`.
- Every module header includes the generated config header:
  `#include "<project-name>/config.h"` (the config include dir is published
  by the aggregate `${PROJECT_NAME}_lib` target).
- Namespace: all modules use the unified namespace defined by
  `PROJECT_NAMESPACE` in `cmake/options.cmake` (default: the project name),
  e.g. `myapp::core`, `myapp::algorithm`. In **all** source files (headers,
  `.cpp`, tests), reference the namespace via the `<namespace-macro>`
  placeholder (e.g. `namespace <namespace-macro>::core { ... }`,
  `<namespace-macro>::core::Greeter`), which is replaced with
  `<PROJECT_NAME_UPPER>` at instantiation so the namespace is configurable at
  configure time. Only `#include` paths use the concrete name
  (`<project-name>/<module>/...`).
- New module = new `src/<mod>/` dir (with its own `CMakeLists.txt` from
  `templates/module-CMakeLists.txt.tmpl` if it has no module dependencies, or
  `templates/module-deps-CMakeLists.txt.tmpl` if it depends on core,
  `include/<project-name>/<mod>/` inside) + `tests/<mod>/` dir; then add
  `add_subdirectory(<mod>)` in
  `src/CMakeLists.txt` and link it into `${PROJECT_NAME}_lib` in the
  top-level `CMakeLists.txt` (two lines).

2. Generate files from templates (copy and replace placeholders):

- `templates/CMakeLists.txt.tmpl` → `CMakeLists.txt` (replace `<project-name>`, `<cxx-standard>`, and `<PROJECT_NAME_UPPER>` placeholders — includes the trailing `if(<PROJECT_NAME_UPPER>_BUILD_TESTS)` block with `enable_testing()` and `add_subdirectory(tests)`)
- `templates/CMakePresets.json.tmpl` → `CMakePresets.json`
- `templates/src-CMakeLists.txt.tmpl` → `src/CMakeLists.txt`
- `templates/options.cmake.tmpl` → `cmake/options.cmake` (replace `<PROJECT_NAME_UPPER>` with the uppercased project name)
- `templates/common.cmake.tmpl` → `cmake/common.cmake` (replace `<PROJECT_NAME_UPPER>` with the uppercased project name)
- `templates/config.h.in.tmpl` → `cmake/config.h.in` (replace `<PROJECT_NAME_UPPER>` and `<project-name>` placeholders)
- `templates/thirdparty.cmake.tmpl` → `cmake/thirdparty.cmake`
- `templates/thirdparty-README.md.tmpl` → `cmake/thirdparty/README.md`
- `templates/thirdparty-googletest.cmake.tmpl` → `cmake/thirdparty/googletest.cmake`
- `templates/gitignore.tmpl` → `.gitignore`
- `templates/README.md.tmpl` → `README.md`
- `templates/module-foo-header.hpp.tmpl` → `src/core/include/<project-name>/core/foo.hpp`
- `templates/module-foo-impl.cpp.tmpl` → `src/core/src/foo.cpp`
- `templates/module-CMakeLists.txt.tmpl` → `src/core/CMakeLists.txt` (replace `<module-name>` with `core`, `<MODULE_NAME_UPPER>` with `CORE`)
- `templates/module-algorithm-foo-header.hpp.tmpl` → `src/algorithm/include/<project-name>/algorithm/foo.hpp`
- `templates/module-algorithm-foo-impl.cpp.tmpl` → `src/algorithm/src/foo.cpp`
- `templates/module-deps-CMakeLists.txt.tmpl` → `src/algorithm/CMakeLists.txt` (replace `<module-name>` with `algorithm`, `<MODULE_NAME_UPPER>` with `ALGORITHM`; the core link is already wired in)

Feel free to adapt the sample `Greeter` (core) and `add`/`greet_sum`
(algorithm, which uses core) to the user's actual use case. Add more modules
if the user asks.

3. Tests (Google Test, on by default — skip only if the user explicitly
   declines):

- `templates/test-core-foo.cpp.tmpl` → `tests/core/foo_test.cpp`
- `templates/test-algorithm-foo.cpp.tmpl` → `tests/algorithm/foo_test.cpp`
- `templates/tests-CMakeLists.txt.tmpl` → `tests/CMakeLists.txt`
- `templates/test-module-CMakeLists.txt.tmpl` → `tests/core/CMakeLists.txt` (replace `<module-name>` with `core`, `<MODULE_NAME_UPPER>` with `CORE`)
- `templates/test-module-CMakeLists.txt.tmpl` → `tests/algorithm/CMakeLists.txt` (replace `<module-name>` with `algorithm`, `<MODULE_NAME_UPPER>` with `ALGORITHM`)
- In `cmake/options.cmake`, set `<PROJECT_NAME_UPPER>_BUILD_TESTS` default to `ON`
  (the googletest module is loaded from `cmake/thirdparty.cmake` under this option)

4. Do NOT initialize a git repository — the skill only generates project
   files. Git initialization/commits are left to the user.

5. Verify the project builds and tests pass (via the presets):

```bash
cmake --preset release && cmake --build --preset release && ctest --preset release
```

(Plain commands `cmake -B build && cmake --build build && ctest --test-dir build`
also work — the release preset is the default configuration.)

Report the created structure and how to build/run.
