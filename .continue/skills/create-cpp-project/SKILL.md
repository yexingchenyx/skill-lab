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
| `<PROJECT_NAME_UPPER>_NAMESPACE_MACRO@` | `DEMO_NAMESPACE` (namespace macro from config.h, used in `namespace X::...` declarations) |

### Placeholder replacement pitfalls (IMPORTANT)

1. **`cmake/config.h.in`**: the `@...@` tokens in it (e.g.
   `@<PROJECT_NAME_UPPER>_NAMESPACE@`, `@<project-name>_VERSION_MAJOR@`) are
   **CMake `configure_file` variables** — they must survive template
   instantiation so CMake can expand them later. When replacing
   `<PROJECT_NAME_UPPER>` / `<project-name>` placeholders, only substitute the
   literal placeholder text; **never** let a sed-like replacement mangle the
   surrounding `@...@` (e.g. `@PJ_NAMESPACE@` must NOT become `@pj`). The
   correct result for project `pj` is:
   ```c
   #define PJ_NAMESPACE @PJ_NAMESPACE@
   #define PJ_NAMESPACE_NAME "@PJ_NAMESPACE_NAME@"
   ```
2. **`module-CMakeLists.txt.tmpl` for `algorithm`**: after instantiation you
   MUST uncomment `target_link_libraries(${PROJECT_NAME}_algorithm PUBLIC
   ${PROJECT_NAME}::core)` — algorithm includes core's headers, and without
   the link the build fails with "pj/core/foo.hpp: No such file or directory".
   For `core` (no dependencies), remove the commented dependency example.

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
  `<PROJECT_NAME_UPPER>_NAMESPACE` in `cmake/options.cmake` (default: the
  project name), e.g. `myapp::core`, `myapp::algorithm`. In **all** source
  files (headers, `.cpp`, tests), reference the namespace via the config.h
  macro `<PROJECT_NAME_UPPER>_NAMESPACE_MACRO@` (e.g.
  `namespace <PROJECT_NAME_UPPER>_NAMESPACE_MACRO@::core { ... }`,
  `<PROJECT_NAME_UPPER>_NAMESPACE_MACRO@::core::Greeter`) so the namespace
  is configurable at configure time. Only `#include` paths use the concrete
  name (`<project-name>/<module>/...`).
- New module = new `src/<mod>/` dir (with its own `CMakeLists.txt` from
  `templates/module-CMakeLists.txt.tmpl`, `include/<project-name>/<mod>/`
  inside) + `tests/<mod>/` dir; then add `add_subdirectory(<mod>)` in
  `src/CMakeLists.txt` and link it into `${PROJECT_NAME}_lib` in the
  top-level `CMakeLists.txt` (two lines).

2. Generate files from templates (copy and replace placeholders):

- `templates/CMakeLists.txt.tmpl` → `CMakeLists.txt` (replace `<project-name>`, `<cxx-standard>`, and `<PROJECT_NAME_UPPER>` placeholders — the if-block uses `if(<PROJECT_NAME_UPPER>_BUILD_TESTS)`)
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
- `templates/module-CMakeLists.txt.tmpl` → `src/core/CMakeLists.txt` (replace `<module-name>` with `core`, `<MODULE_NAME_UPPER>` with `CORE`; remove the commented dependency example)
- `templates/module-algorithm-foo-header.hpp.tmpl` → `src/algorithm/include/<project-name>/algorithm/foo.hpp`
- `templates/module-algorithm-foo-impl.cpp.tmpl` → `src/algorithm/src/foo.cpp`
- `templates/module-CMakeLists.txt.tmpl` → `src/algorithm/CMakeLists.txt` (replace `<module-name>` with `algorithm`, `<MODULE_NAME_UPPER>` with `ALGORITHM`; uncomment the dependency line so it links `${PROJECT_NAME}::core` PUBLIC)

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
- Append the contents of `templates/CMakeLists-tests.inc.cmake` to `CMakeLists.txt`
- In `cmake/options.cmake`, set `<PROJECT_NAME_UPPER>_BUILD_TESTS` default to `ON`
  (the googletest module is loaded from `cmake/thirdparty.cmake` under this option)

4. Initialize git repo and make an initial commit (if user agrees):

```bash
git init && git add . && git commit -m "Initial commit

Generated with [Continue](https://continue.dev)

Co-Authored-By: Continue <noreply@continue.dev>"
```

5. Verify the project builds and tests pass (via the presets):

```bash
cmake --preset release && cmake --build --preset release && ctest --preset release
```

(Plain commands `cmake -B build && cmake --build build && ctest --test-dir build`
also work — the release preset is the default configuration.)

Report the created structure and how to build/run.
