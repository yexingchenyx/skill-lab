# cp

C++ project built with CMake (C++20), vcpkg manifest mode.

## Build

Presets are defined in `CMakePresets.json` (vcpkg toolchain and
`BUILD_SHARED_LIBS=ON` wired in the `base` preset):

```bash
cmake --preset release && cmake --build --preset release
ctest --preset release          # run tests
```

Available presets: `release`, `debug`, `release-static` / `debug-static`
(static libraries, `BUILD_SHARED_LIBS=OFF`).

Dependencies are installed automatically by vcpkg manifest mode at
configure time (see `vcpkg.json`; versions pinned by
`vcpkg-configuration.json`).

## Run

Build artifacts go to `build/output/<config>/` (see `cmake/common.cmake`):

```bash
./build/output/Release/bin/cp
```

## Build configuration

`cmake/common.cmake` generates `cp/config.h` (from
`cmake/config.h.in`) into `<source-dir>/include/` (git-ignored). It exposes the
project version, build options (e.g. `CP_BUILD_TESTS`),
the unified namespace (`CP_NS`), the library export macro
(`CP_API`), git commit and build time. Include it
uniformly as:

```cpp
#include "cp/config.h"
```
