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

Replace every occurrence in each generated file:

| Placeholder     | Example (project `myapp`) |
|-----------------|---------------------------|
| `<project-name>`| `myapp`                   |
| `<project-name-dashed>` | `my-app` (underscores → dashes; used in `vcpkg.json` name) |
| `<PROJECT_NAME_UPPER>` | `MYAPP`            |
| `<cxx-standard>`| `20`                      |

The vcpkg baseline is **not** a placeholder — it is hardcoded
(`fa8cecf91d7f31a1715a7a6524f208897ffb33ce`) in
`templates/vcpkg.json.tmpl` and `templates/vcpkg-configuration.json.tmpl`.
Copy those templates as-is; do not query the local vcpkg or network.

### Placeholder replacement rules (IMPORTANT)

- **Replace placeholders per-file, not globally.** Several templates are
  instantiated multiple times with different values (e.g.
  `test-module-CMakeLists.txt.tmpl` becomes both `tests/core/CMakeLists.txt`
  and `tests/algorithm/CMakeLists.txt`). A global `<module-name>` → `core`
  replacement would exhaust the placeholder before `algorithm`, producing
  duplicate target names and a CMake configure error
  (`TARGET ... was not created in this directory`).
  **Copy each template to its destination first, then run the placeholder
  replacement for that destination file only.**
- A plain literal replacement of the placeholders above can never break
  anything else: every `@...@` token in `cmake/config.h.in` is a CMake
  `configure_file` variable with a fixed name containing no placeholders
  (`@PROJECT_VERSION@`, `@PROJECT_NAMESPACE@`, `@PROJECT_DEBUG@`,
  `@PROJECT_GIT_COMMIT@`, `@PROJECT_BUILD_TIME@`) — do not rename these.
- After replacement, verify no placeholders remain:
  `grep -rn '<project-name\|<PROJECT_NAME_UPPER\|<module-name\|<MODULE_NAME_UPPER\|<cxx-standard>' <project-dir>`
  must return nothing (standard-library `#include <string>` style lines are
  fine).

## Steps

1. Generate files from templates (copy each to its destination, then replace
   placeholders in that file only; "(as-is)" = no placeholders, plain copy):

Note: create all destination directories first (`mkdir -p`), since plain
`cp` does not create parent directories.

```
templates/CMakeLists.txt.tmpl              → CMakeLists.txt
templates/CMakePresets.json.tmpl           → CMakePresets.json
templates/vcpkg.json.tmpl                  → vcpkg.json          (only <project-name-dashed>)
templates/vcpkg-configuration.json.tmpl    → vcpkg-configuration.json  (as-is)
templates/src-CMakeLists.txt.tmpl          → src/CMakeLists.txt  (as-is)
templates/options.cmake.tmpl               → cmake/options.cmake
templates/common.cmake.tmpl                → cmake/common.cmake
templates/config.h.in.tmpl                 → cmake/config.h.in
templates/thirdparty.cmake.tmpl            → cmake/thirdparty.cmake
templates/thirdparty-README.md.tmpl        → cmake/thirdparty/README.md  (as-is)
templates/thirdparty-googletest.cmake.tmpl → cmake/thirdparty/googletest.cmake
templates/thirdparty-cli11.cmake.tmpl      → cmake/thirdparty/cli11.cmake  (as-is)
templates/gitignore.tmpl                   → .gitignore  (as-is)
templates/README.md.tmpl                   → README.md

templates/module-foo-header.hpp.tmpl       → src/core/include/<project-name>/core/foo.hpp
templates/module-foo-impl.cpp.tmpl         → src/core/src/foo.cpp
templates/module-CMakeLists.txt.tmpl       → src/core/CMakeLists.txt        (<module-name>=core, <MODULE_NAME_UPPER>=CORE)
templates/module-algorithm-foo-header.hpp.tmpl → src/algorithm/include/<project-name>/algorithm/foo.hpp
templates/module-algorithm-foo-impl.cpp.tmpl   → src/algorithm/src/foo.cpp
templates/module-deps-CMakeLists.txt.tmpl  → src/algorithm/CMakeLists.txt   (<module-name>=algorithm, <MODULE_NAME_UPPER>=ALGORITHM; core link already wired)

templates/cli-CMakeLists.txt.tmpl          → cli/CMakeLists.txt  (as-is)
templates/cli-common-CMakeLists.txt.tmpl   → cli/common/CMakeLists.txt  (as-is)
templates/cli-common-include/util.hpp.tmpl → cli/common/include/<project-name>/cli/util.hpp
templates/cli-common-src-util.cpp.tmpl     → cli/common/src/util.cpp
templates/cli-foo-CMakeLists.txt.tmpl      → cli/foo/CMakeLists.txt  (as-is)
templates/cli-foo-main.cpp.tmpl            → cli/foo/main.cpp

templates/test-core-foo.cpp.tmpl           → tests/core/foo_test.cpp
templates/test-algorithm-foo.cpp.tmpl      → tests/algorithm/foo_test.cpp
templates/tests-CMakeLists.txt.tmpl        → tests/CMakeLists.txt
templates/test-common-CMakeLists.txt.tmpl  → tests/common/CMakeLists.txt  (as-is)
templates/tests-common-include/tests-util.hpp.tmpl → tests/common/include/<project-name>/tests/util.hpp
templates/test-common-src-util.cpp.tmpl    → tests/common/src/util.cpp
templates/test-module-CMakeLists.txt.tmpl  → tests/core/CMakeLists.txt      (<module-name>=core, <MODULE_NAME_UPPER>=CORE)
templates/test-module-CMakeLists.txt.tmpl  → tests/algorithm/CMakeLists.txt (<module-name>=algorithm, <MODULE_NAME_UPPER>=ALGORITHM)
```

Feel free to adapt the sample `Greeter` (core) and `add`/`greet_sum`
(algorithm, which uses core) to the user's actual use case. Add more modules
if the user asks.

2. Tests (Google Test, on by default — skip only if the user explicitly
   declines) are covered by the `tests/` mappings above.

3. Do NOT initialize a git repository — the skill only generates project
   files. Git initialization/commits are left to the user.

4. Verify the project builds and tests pass (via the presets):

```bash
cmake --preset release && cmake --build --preset release && ctest --preset release
```

(Plain commands `cmake -B build && cmake --build build && ctest --test-dir build`
also work.)

Report the created structure and how to build/run.

## Generated layout & conventions (reference)

The templates produce this structure — the conventions below are already
implemented in the templates; do not re-implement them:

```
<project-name>/
├── CMakeLists.txt                  # add_subdirectory per module; INTERFACE aggregate ${PROJECT_NAME}_lib
├── CMakePresets.json               # presets: release, debug, release-static, debug-static
├── vcpkg.json / vcpkg-configuration.json
├── cmake/                          # options.cmake (vcpkg toolchain, included BEFORE project()),
│                                   # common.cmake, config.h.in, thirdparty.cmake, thirdparty/<lib>.cmake
├── src/<module>/                   # one self-contained dir per module (core, algorithm)
│   ├── CMakeLists.txt              # target <project>_<module> + ALIAS <project>::<module>
│   ├── include/<project-name>/<module>/
│   └── src/
├── cli/                            # common/ (static lib <project>_cli_common) + foo/ (demo tool <project>_cli_foo)
└── tests/<module>/                 # one test target <project>_<module>_tests per module
```

Key conventions (details are commented inside the templates):

- **vcpkg (default ON)**: base preset sets `<PROJECT_NAME_UPPER>_USE_VCPKG=ON`
  and `<PROJECT_NAME_UPPER>_VCPKG_ROOT`; `options.cmake` sets
  `CMAKE_TOOLCHAIN_FILE` and must be included before `project()`.
  `vcpkg-configuration.json` must keep `default-registry.baseline`
  (hardcoded in the template) — it is the single source of the baseline;
  `vcpkg.json` intentionally has no `builtin-baseline`.
  Deps install into `<project>/install/vcpkg/<triplet>/`
  (`<PRJ>_DOWNLOAD_ROOT/vcpkg`, set in `cmake/options.cmake`), shared
  across presets.
- **Third-party local-first**: each `cmake/thirdparty/<lib>.cmake` tries
  `find_package(<lib> QUIET)` first, falls back to `FetchContent`, and prints
  a STATUS summary. When `FetchContent` is used, `FETCHCONTENT_BASE_DIR` is
  set to `<project>/dep_installed/fetchcontent` (outside `build/`, survives
  `rm -rf build`). Every dependency must expose a namespaced target
  (`<lib>::<lib>`); never leak include dirs/definitions globally. Full rules:
  `cmake/thirdparty/README.md`. Keep `vcpkg.json` in sync when adding
  libraries via `cpp-add-thirdparty`.
- **Dynamic vs static via presets**: `BUILD_SHARED_LIBS=ON` in the base
  preset; `release-static`/`debug-static` set it OFF. Module CMakeLists use a
  plain `add_library(...)` — no source edits needed to switch.
- **Unified export macro**: single `<PROJECT_NAME_UPPER>_API` macro from the
  generated `config.h`; each module defines `<PROJECT_NAME_UPPER>_EXPORTS`
  (PRIVATE) while building itself. No per-module export headers.
- **Module deps**: expressed with `target_link_libraries` using namespaced
  aliases (e.g. `algorithm` links `<project-name>::core` PUBLIC). The app and
  tests link `${PROJECT_NAME}_lib`; CLI executables link
  `<project-name>::cli_common`.
- **tests/common** (`<project>_test_common`) must be added via
  `add_subdirectory(common)` before module test subdirectories.
- **Headers**: path mirrors the module
  (`#include "<project-name>/<module-name>/<module-name>.hpp"`); every module
  header includes the generated `#include "<project-name>/config.h"`.
- **Namespace**: unified via `<PROJECT_NAME_UPPER>_NAMESPACE` (default:
  project name; set in the base preset; override with
  `-D<PRJ>_NAMESPACE=...`).
- **New module**: new `src/<mod>/` (CMakeLists from
  `templates/module-CMakeLists.txt.tmpl`, or
  `templates/module-deps-CMakeLists.txt.tmpl` if it depends on core) +
  `tests/<mod>/`; then add `add_subdirectory(<mod>)` in `src/CMakeLists.txt`
  and link it into `${PROJECT_NAME}_lib` (two lines). New CLI tools: new
  `cli/<tool>/` dir + `add_subdirectory(<tool>)` in `cli/CMakeLists.txt`.
